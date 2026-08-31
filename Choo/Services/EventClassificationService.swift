import Foundation

/// Classifies calendar events into visual registers (fun / utility / routine) with Haiku.
/// One snapshot-driven backfill covers create, edit, web-created and historical events:
/// results are written straight onto the event doc, so the doc is the cache and the
/// snapshot listener delivers the upgrade back to every client.
@MainActor
@Observable
final class EventClassificationService {
    static let shared = EventClassificationService()

    @ObservationIgnored private let claude = ClaudeAPIService.shared
    @ObservationIgnored private var isRunning = false
    /// Attempts per event this session — stops hot loops on events Haiku keeps
    /// answering invalidly. Only counted when the API actually responded, so
    /// being offline never exhausts the budget.
    @ObservationIgnored private var attemptCounts: [String: Int] = [:]
    /// Results written but not yet round-tripped through the snapshot listener,
    /// with write time — entries expire so a rename racing a write can't wedge
    /// an event out of reclassification for the whole session.
    @ObservationIgnored private var pendingWrites: [String: Date] = [:]

    private static let maxAttempts = 3
    private static let batchSize = 10
    private static let pendingWriteTTL: TimeInterval = 30

    private struct BatchResponse: Decodable {
        struct Item: Decodable {
            let id: String
            let register: String
            let subtype: String
            let glyph: String
            let sceneEmoji: [String]?
            let confidence: Double?
        }
        let results: [Item]
    }

    private static let systemPrompt = """
    You classify family calendar events into a visual register for a calendar app. \
    Respond with STRICT JSON only, no prose: {"results":[{"id":"...","register":"fun|utility|routine","subtype":"celebration|social|trip|health|errand|admin|recurring","glyph":"one emoji","sceneEmoji":["up to 3 emoji"],"confidence":0.0}]}

    Rules:
    - fun = things the family looks forward to: birthdays, parties, celebrations, dinners out, brunch, lunches with friends, outings, holidays and trips.
    - utility = obligations: health appointments (doctor, dentist, physio), tradespeople, car service, errands, school admin, work meetings.
    - routine = recurring rhythm: weekly/fortnightly lessons, training, sport practice, bin night. Recurring lessons and training are routine even when kids are attached.
    - A birthday or celebration stored as recurring is still fun, not routine.
    - subtype: celebration (birthdays, parties, anniversaries), social (meals out, catch-ups), trip (holidays, travel, weekends away), health, errand, admin, recurring.
    - Multi-day all-day events that read like travel or a holiday are subtype "trip".
    - glyph: the single most fitting emoji. sceneEmoji: 2-3 large decorative emoji for fun events (e.g. ["🎂","🎈","✨"]); [] for utility/routine.
    - confidence: 0-1. If unsure, use a low confidence — the app quietly falls back.
    - Return one result per input event, matching ids exactly.
    """

    /// Classify every stale candidate among `events`, soonest first, in small serial batches.
    /// Safe to call repeatedly — it no-ops while a run is in flight and skips events
    /// already attempted too often or awaiting a snapshot round-trip.
    func classifyStaleEvents(_ events: [FamilyEvent], familyId: String, firestoreService: FirestoreService) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date())) ?? Date()

        let now = Date()
        let candidates = events
            .filter { event in
                guard let id = event.id else { return false }
                guard event.needsClassification else { return false }
                if let written = pendingWrites[id], now.timeIntervalSince(written) < Self.pendingWriteTTL { return false }
                guard attemptCounts[id, default: 0] < Self.maxAttempts else { return false }
                // Skip deep history — hidden by default, utility fallback is fine there
                return event.endDate >= cutoff || event.recurrence != nil
            }
            .sorted { $0.startDate < $1.startDate }

        guard !candidates.isEmpty else { return }

        var backoff: Duration = .seconds(2)
        for batch in stride(from: 0, to: candidates.count, by: Self.batchSize).map({ Array(candidates[$0..<min($0 + Self.batchSize, candidates.count)]) }) {
            do {
                try await classifyBatch(batch, familyId: familyId, firestoreService: firestoreService)
                backoff = .seconds(2)
            } catch {
                // Network/API failure: no attempt is charged — retry next kick
                try? await Task.sleep(for: backoff)
                backoff = min(backoff * 2, .seconds(30))
            }
            try? await Task.sleep(for: .milliseconds(400))
        }
    }

    private func classifyBatch(_ batch: [FamilyEvent], familyId: String, firestoreService: FirestoreService) async throws {
        let byId = Dictionary(uniqueKeysWithValues: batch.compactMap { e in e.id.map { ($0, e) } })
        let prompt = "Classify these events:\n" + batch.compactMap { event -> String? in
            guard let id = event.id else { return nil }
            var parts = ["id: \(id)", "title: \(event.title)"]
            if event.isAllDay == true { parts.append("all-day, spans \(event.spanDayCount + 1) day(s)") }
            if let freq = event.recurrence { parts.append("recurring \(freq.displayName.lowercased())") }
            if let loc = event.location, !loc.isEmpty { parts.append("location: \(loc)") }
            parts.append("attendees: \((event.attendeeUIDs ?? []).count)")
            return "- " + parts.joined(separator: ", ")
        }.joined(separator: "\n")

        let response: BatchResponse = try await claude.callClaudeJSON(system: Self.systemPrompt, prompt: prompt, maxTokens: 1200)

        // The API answered — charge one attempt per event in the batch
        for event in batch {
            if let id = event.id { attemptCounts[id, default: 0] += 1 }
        }

        for item in response.results {
            guard let event = byId[item.id], let eventId = event.id else { continue }
            let classification = EventClassification(
                register: EventRegister(rawValue: item.register)?.rawValue ?? EventRegister.utility.rawValue,
                subtype: EventSubtype(lenient: item.subtype).rawValue,
                glyph: String(item.glyph.prefix(4)),
                sceneEmoji: Array((item.sceneEmoji ?? []).prefix(3)),
                confidence: min(max(item.confidence ?? 0, 0), 1),
                classifiedTitle: event.title,
                classifiedAt: Date()
            )
            pendingWrites[eventId] = Date()
            do {
                try await firestoreService.updateEventClassification(familyId: familyId, eventId: eventId, classification: classification)
            } catch {
                pendingWrites.removeValue(forKey: eventId)
            }
        }
    }

    /// Called when a snapshot arrives — pending writes that round-tripped (or expired) are released.
    func reconcile(with events: [FamilyEvent]) {
        guard !pendingWrites.isEmpty else { return }
        let now = Date()
        for event in events {
            if let id = event.id, event.hasFreshClassification {
                pendingWrites.removeValue(forKey: id)
            }
        }
        pendingWrites = pendingWrites.filter { now.timeIntervalSince($0.value) < Self.pendingWriteTTL }
    }
}
