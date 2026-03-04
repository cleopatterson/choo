import AppIntents
import FirebaseFirestore

struct AddEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Event"
    static var description: IntentDescription = "Add a calendar event to Choo"

    @Parameter(title: "Event Title")
    var eventTitle: String

    @Parameter(title: "Date")
    var date: Date

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard SharedUserContext.isLoggedIn,
              let familyId = SharedUserContext.familyId,
              let displayName = SharedUserContext.displayName else {
            return .result(dialog: "Please open Choo and sign in first.")
        }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        let db = Firestore.firestore()
        let attendees: [String] = SharedUserContext.uid.map { [$0] } ?? []
        let data: [String: Any] = [
            "familyId": familyId,
            "title": eventTitle,
            "startDate": Timestamp(date: startOfDay),
            "endDate": Timestamp(date: endOfDay),
            "createdBy": displayName,
            "isAllDay": true,
            "attendeeUIDs": attendees,
            "reminderEnabled": true
        ]

        try await db.collection("families").document(familyId)
            .collection("events")
            .addDocument(data: data)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)

        return .result(dialog: "Added \(eventTitle) on \(dateStr) to your calendar.")
    }
}
