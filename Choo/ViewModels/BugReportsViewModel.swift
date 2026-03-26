import Foundation

@MainActor
@Observable
final class BugReportsViewModel {
    let firestoreService: FirestoreService
    let familyId: String
    let displayName: String

    var showingBugEditor = false
    var editingBugReport: BugReport?
    var errorMessage: String?

    init(firestoreService: FirestoreService, familyId: String, displayName: String) {
        self.firestoreService = firestoreService
        self.familyId = familyId
        self.displayName = displayName
        firestoreService.listenToBugReports(familyId: familyId)
    }

    var bugReports: [BugReport] {
        firestoreService.bugReports.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createBugReport(title: String, description: String, severity: BugSeverity) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        errorMessage = nil

        do {
            try await firestoreService.createBugReport(
                familyId: familyId,
                title: trimmedTitle,
                description: description,
                createdBy: displayName,
                severity: severity
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBugReport(_ report: BugReport) async {
        guard let reportId = report.id else { return }
        errorMessage = nil

        do {
            try await firestoreService.deleteBugReport(familyId: familyId, reportId: reportId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
