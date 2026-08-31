import SwiftUI

/// The fixed left gutter for a day group: day number over a small uppercase weekday.
struct DayGutterView: View {
    let day: Date
    let isToday: Bool
    let isPast: Bool

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isToday {
                // Google-style filled day chip
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CalendarTheme.avatarRing)
                    .frame(width: 30, height: 30)
                    .background(CalendarTheme.accentLilac, in: Circle())
            } else {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white.opacity(isPast ? 0.5 : 0.85))
            }

            Text(Self.weekdayFormatter.string(from: day).uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(isToday ? CalendarTheme.accentLilac.opacity(0.75) : .white.opacity(isPast ? 0.2 : 0.35))
                .padding(.leading, isToday ? 3 : 0)
        }
        .frame(width: 40, alignment: .leading)
        .padding(.top, 4)
    }
}
