import SwiftUI

/// Full-bleed seasonal band between months: layered gradients, drifting translucent
/// bubbles, serif month name over a scrim. Reinstates the full-bleed month treatment.
struct MonthHeroView: View {
    let monthDate: Date

    @State private var drifting = false

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    private var month: Int { Calendar.current.component(.month, from: monthDate) }

    var body: some View {
        let theme = Self.theme(for: month)

        ZStack(alignment: .bottomLeading) {
            // Base wash — deep purple-navy
            LinearGradient(
                colors: [Color(red: 0.141, green: 0.106, blue: 0.271), Color(red: 0.102, green: 0.082, blue: 0.208), Color(red: 0.090, green: 0.071, blue: 0.169)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Seasonal colour accents
            RadialGradient(colors: [theme.primary.opacity(0.28), .clear], center: .init(x: 0.85, y: -0.1), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [theme.secondary.opacity(0.15), .clear], center: .init(x: 0.1, y: 1.1), startRadius: 0, endRadius: 200)
            RadialGradient(colors: [CalendarTheme.basePurple.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 300)

            // Drifting bubbles — staggered by duration, not delay
            bubble(size: 70, x: 300, y: 40, duration: 9)
            bubble(size: 42, x: 236, y: 86, duration: 12)
            bubble(size: 26, x: 330, y: 118, duration: 15)

            // Scrim so the text plate reads
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.090, green: 0.071, blue: 0.169).opacity(0.55), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.7),
                    .init(color: Color(red: 0.090, green: 0.071, blue: 0.169).opacity(0.75), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(Self.monthFormatter.string(from: monthDate))
                    .font(.custom("Georgia", size: 36))
                    .foregroundStyle(.white)
                Text(theme.tagline)
                    .font(.custom("Georgia-Italic", size: 13))
                    .foregroundStyle(Color(red: 0.929, green: 0.914, blue: 0.996).opacity(0.65))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .frame(height: 168)
        .clipped()
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drifting = true
            }
        }
    }

    private func bubble(size: CGFloat, x: CGFloat, y: CGFloat, duration: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white.opacity(0.4), CalendarTheme.celebrationHue.opacity(0.15), CalendarTheme.basePurple.opacity(0.06)],
                    center: .init(x: 0.32, y: 0.28), startRadius: 0, endRadius: size * 0.7
                )
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .frame(width: size, height: size)
            .position(x: x, y: y)
            .offset(x: drifting ? 4 : -4, y: drifting ? -7 : 4)
            .animation(
                UIAccessibility.isReduceMotionEnabled
                    ? nil
                    : .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: drifting
            )
    }

    // MARK: - Seasonal themes (Southern Hemisphere)

    private struct MonthTheme {
        let primary: Color
        let secondary: Color
        let tagline: String
    }

    private static func theme(for month: Int) -> MonthTheme {
        switch month {
        case 1:  return MonthTheme(primary: .orange, secondary: .yellow, tagline: "Peak summer")
        case 2:  return MonthTheme(primary: .pink, secondary: .red, tagline: "Love & late summer")
        case 3:  return MonthTheme(primary: .orange, secondary: .brown, tagline: "Autumn begins")
        case 4:  return MonthTheme(primary: .teal, secondary: .gray, tagline: "Autumn rains")
        case 5:  return MonthTheme(primary: .brown, secondary: .orange, tagline: "Cosy autumn")
        case 6:  return MonthTheme(primary: .cyan, secondary: .blue, tagline: "Winter arrives")
        case 7:  return MonthTheme(primary: .blue, secondary: .indigo, tagline: "Deep winter")
        case 8:  return MonthTheme(primary: .indigo, secondary: .cyan, tagline: "Winter's end")
        case 9:  return MonthTheme(primary: Color(red: 0.176, green: 0.831, blue: 0.749), secondary: Color(red: 0.639, green: 0.902, blue: 0.208), tagline: "Spring arrives")
        case 10: return MonthTheme(primary: .purple, secondary: .orange, tagline: "Halloween")
        case 11: return MonthTheme(primary: .green, secondary: .mint, tagline: "Late spring")
        case 12: return MonthTheme(primary: .red, secondary: .green, tagline: "Christmas & summer")
        default: return MonthTheme(primary: .blue, secondary: .purple, tagline: "")
        }
    }
}
