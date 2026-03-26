import Foundation

@MainActor
@Observable
final class NotesViewModel {
    let firestoreService: FirestoreService
    let familyId: String
    let displayName: String

    var showingNoteEditor = false
    var editingNote: Note?
    var errorMessage: String?

    init(firestoreService: FirestoreService, familyId: String, displayName: String) {
        self.firestoreService = firestoreService
        self.familyId = familyId
        self.displayName = displayName
        firestoreService.listenToNotes(familyId: familyId)
    }

    var notes: [Note] {
        firestoreService.notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createNote(title: String, content: String, isList: Bool) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        errorMessage = nil

        do {
            try await firestoreService.createNote(
                familyId: familyId,
                title: trimmedTitle,
                content: content,
                createdBy: displayName,
                isList: isList
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNote(noteId: String, title: String, content: String) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        errorMessage = nil

        do {
            try await firestoreService.updateNote(
                familyId: familyId,
                noteId: noteId,
                title: trimmedTitle,
                content: content
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteNote(_ note: Note) async {
        guard let noteId = note.id else { return }
        errorMessage = nil

        do {
            try await firestoreService.deleteNote(familyId: familyId, noteId: noteId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
