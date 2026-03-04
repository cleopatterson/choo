import Foundation

struct PendingNote: Codable {
    let title: String
    let content: String
    let createdAt: Date
}

enum PendingShareManager {
    private static let suiteName = "group.com.tonywall.wallboard"
    private static let fileName = "pending_shares.json"

    private static var containerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent(fileName)
    }

    static func addPendingNote(title: String, content: String) {
        var notes = readPendingNotes()
        notes.append(PendingNote(title: title, content: content, createdAt: Date()))
        save(notes)
    }

    static func readPendingNotes() -> [PendingNote] {
        guard let url = containerURL,
              let data = try? Data(contentsOf: url),
              let notes = try? JSONDecoder().decode([PendingNote].self, from: data) else {
            return []
        }
        return notes
    }

    static func clearPendingNotes() {
        guard let url = containerURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func save(_ notes: [PendingNote]) {
        guard let url = containerURL,
              let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
