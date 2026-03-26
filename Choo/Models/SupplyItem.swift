import Foundation
import FirebaseFirestore

enum SupplyCategory: String, Codable, CaseIterable {
    case coldGoods
    case breakfast
    case pantry
    case cleaning

    var displayName: String {
        switch self {
        case .coldGoods: "Cold Goods"
        case .breakfast: "Breakfast"
        case .pantry: "Pantry"
        case .cleaning: "Cleaning"
        }
    }

    var emoji: String {
        switch self {
        case .coldGoods: "🧊"
        case .breakfast: "🥣"
        case .pantry: "🥫"
        case .cleaning: "🧹"
        }
    }

    var sortIndex: Int {
        switch self {
        case .coldGoods: 0
        case .breakfast: 1
        case .pantry: 2
        case .cleaning: 3
        }
    }
}

enum SupplyCadence: String, Codable, CaseIterable {
    case weekly
    case fortnightly
    case monthly
    case quarterly
    case adHoc

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .fortnightly: "Fortnightly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .adHoc: "Ad hoc"
        }
    }

    var days: Int {
        switch self {
        case .weekly: 7
        case .fortnightly: 14
        case .monthly: 30
        case .quarterly: 90
        case .adHoc: Int.max // never auto-due
        }
    }
}

enum SupplyStatus {
    case ok
    case due
    case low

    var displayName: String {
        switch self {
        case .ok: "OK"
        case .due: "Due"
        case .low: "Running low"
        }
    }
}

struct SupplyItem: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var emoji: String?
    var category: SupplyCategory
    var cadence: SupplyCadence
    var aisleOrder: Int
    var lastPurchasedDate: Date?
    var isLow: Bool?

    var status: SupplyStatus {
        if isLow == true { return .low }
        guard let lastPurchased = lastPurchasedDate else { return .due }
        let daysSince = Calendar.current.dateComponents([.day], from: lastPurchased, to: Date()).day ?? 0
        if daysSince >= cadence.days { return .due }
        return .ok
    }

    var isDueOrLow: Bool {
        status == .due || status == .low
    }
}
