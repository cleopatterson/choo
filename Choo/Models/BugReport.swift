import Foundation
import FirebaseFirestore

enum BugSeverity: String, Codable, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

enum BugStatus: String, Codable, CaseIterable, Identifiable {
    case open, inProgress, fixed, closed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .fixed: "Fixed"
        case .closed: "Closed"
        }
    }
}

struct BugReport: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var title: String
    var description: String
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var severity: String
    var status: String
    var githubIssueUrl: String?
    var githubIssueNumber: Int?

    var severityEnum: BugSeverity {
        BugSeverity(rawValue: severity) ?? .medium
    }

    var statusEnum: BugStatus {
        BugStatus(rawValue: status) ?? .open
    }
}
