import SwiftUI

/// Palette and register styling for the calendar agenda.
/// Values follow the approved prototype (Calendar Final, option 11a).
enum CalendarTheme {
    // MARK: - Shared

    /// #c4b5fd — today's gutter, month season line.
    static let accentLilac = Color(red: 0.769, green: 0.710, blue: 0.992)
    /// #1c1535 — the ring separating overlapping avatars from the card.
    static let avatarRing = Color(red: 0.110, green: 0.082, blue: 0.208)
    /// rgba(237,233,254,.6) — meta/time lines.
    static let textDim = Color(red: 0.929, green: 0.914, blue: 0.996).opacity(0.6)
    /// rgba(237,233,254,.35) — whispers and routine time.
    static let textFaint = Color(red: 0.929, green: 0.914, blue: 0.996).opacity(0.35)

    // MARK: - Quiet cards (utility + routine)

    /// rgba(139,92,246,.06)
    static let quietFill = Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.06)
    /// rgba(139,92,246,.12)
    static let quietStroke = Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.12)

    /// 3pt utility category left-borders.
    static let healthBorder = Color(red: 0.369, green: 0.918, blue: 0.831).opacity(0.5)   // teal
    static let errandBorder = Color(red: 0.580, green: 0.639, blue: 0.722).opacity(0.45)  // slate
    static let adminBorder = Color(red: 0.784, green: 0.557, blue: 0.655).opacity(0.5)    // rose

    static func utilityBorder(for subtype: EventSubtype) -> Color {
        switch subtype {
        case .health: return healthBorder
        case .admin: return adminBorder
        default: return errandBorder
        }
    }

    // MARK: - Fun tints

    /// rgba(196,128,255,…) purple — birthdays, parties.
    static let celebrationHue = Color(red: 0.769, green: 0.502, blue: 1.0)
    /// rgba(255,158,196,…) pink tail of the celebration gradient.
    static let celebrationPink = Color(red: 1.0, green: 0.620, blue: 0.769)
    /// rgba(251,176,110,…) amber — meals out, catch-ups.
    static let socialHue = Color(red: 0.984, green: 0.690, blue: 0.431)
    /// rgba(251,200,150,…) — social today-glow border.
    static let socialGlowStroke = Color(red: 0.984, green: 0.784, blue: 0.588)
    /// rgba(56,189,248,…) sky — trips and the holiday bleed.
    static let tripHue = Color(red: 0.220, green: 0.741, blue: 0.973)
    /// #8B5CF6 base purple used inside fun gradients.
    static let basePurple = Color(red: 0.545, green: 0.361, blue: 0.965)

    enum FunTint {
        case celebration
        case social
        case trip

        var hue: Color {
            switch self {
            case .celebration: return CalendarTheme.celebrationHue
            case .social: return CalendarTheme.socialHue
            case .trip: return CalendarTheme.tripHue
            }
        }

        var stroke: Color {
            switch self {
            case .celebration: return CalendarTheme.celebrationHue.opacity(0.32)
            case .social: return CalendarTheme.socialGlowStroke.opacity(0.6)
            case .trip: return CalendarTheme.tripHue.opacity(0.35)
            }
        }

        var gradient: LinearGradient {
            switch self {
            case .celebration:
                return LinearGradient(
                    colors: [CalendarTheme.celebrationHue.opacity(0.2), CalendarTheme.basePurple.opacity(0.1), CalendarTheme.celebrationPink.opacity(0.13)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .social:
                return LinearGradient(
                    colors: [CalendarTheme.socialHue.opacity(0.2), CalendarTheme.basePurple.opacity(0.1)],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
            case .trip:
                return LinearGradient(
                    colors: [CalendarTheme.tripHue.opacity(0.18), CalendarTheme.basePurple.opacity(0.1)],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
            }
        }
    }

    static func funTint(for subtype: EventSubtype) -> FunTint {
        switch subtype {
        case .social: return .social
        case .trip: return .trip
        default: return .celebration
        }
    }
}

// MARK: - Anticipation ramp

/// How close a FUN event is — drives scene vividness and countdown voice.
/// Pure date math; never the classifier's job.
enum RampStage: Equatable {
    case past
    case today
    case near(days: Int)     // 1–2 days
    case week(days: Int)     // 3–13 days
    case distant(days: Int)  // ≥ 2 weeks

    static func stage(for eventDay: Date, today: Date = Date()) -> RampStage {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: today), to: cal.startOfDay(for: eventDay)).day ?? 0
        if days < 0 { return .past }
        if days == 0 { return .today }
        if days <= 2 { return .near(days: days) }
        if days <= 13 { return .week(days: days) }
        return .distant(days: days)
    }

    var sceneOpacity: Double {
        switch self {
        case .past: return 0.3
        case .today: return 1
        case .near: return 0.85
        case .week: return 0.68
        case .distant: return 0.4
        }
    }

    var sceneSaturation: Double {
        switch self {
        case .past: return 0.55
        case .today: return 1
        case .near: return 1
        case .week: return 0.8
        case .distant: return 0.55
        }
    }

    var hasGlow: Bool {
        switch self {
        case .today, .near: return true
        default: return false
        }
    }

    private static let numberWords = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

    /// Whispers spell numbers ("two weeks away…"); chips use digits ("in 6 days").
    var countdownText: String {
        switch self {
        case .past: return ""
        case .today: return "Today! 🎈"
        case .near(let days), .week(let days):
            return days == 1 ? "tomorrow" : "in \(days) days"
        case .distant(let days):
            let weeks = Int((Double(days) / 7).rounded())
            let word = Self.numberWords.indices.contains(weeks) ? Self.numberWords[weeks] : "\(weeks)"
            return "\(word) weeks away…"
        }
    }
}
