import SwiftUI

enum TabAccent {
    case calendar
    case shopping
    case exercise
    case house

    var color: Color {
        switch self {
        case .calendar: .chooPurple
        case .shopping: .chooAmber
        case .exercise: .chooTeal
        case .house: .chooRose
        }
    }

    var heroGradientColors: [Color] {
        switch self {
        case .calendar:
            [
                Color(red: 0.14, green: 0.08, blue: 0.32),
                Color(red: 0.20, green: 0.12, blue: 0.40),
                Color(red: 0.12, green: 0.10, blue: 0.30)
            ]
        case .shopping:
            [
                Color(red: 0.32, green: 0.18, blue: 0.06),
                Color(red: 0.40, green: 0.24, blue: 0.08),
                Color(red: 0.28, green: 0.16, blue: 0.04)
            ]
        case .exercise:
            [
                Color(red: 0.106, green: 0.263, blue: 0.196),
                Color(red: 0.176, green: 0.416, blue: 0.310),
                Color(red: 0.251, green: 0.569, blue: 0.424)
            ]
        case .house:
            [
                Color(red: 0.30, green: 0.16, blue: 0.22),
                Color(red: 0.36, green: 0.20, blue: 0.28),
                Color(red: 0.26, green: 0.14, blue: 0.24)
            ]
        }
    }
}
