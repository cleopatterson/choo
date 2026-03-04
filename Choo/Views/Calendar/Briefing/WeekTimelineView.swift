import SwiftUI

struct WeekTimelineView: View {
    let weekDays: [Date]
    let eventCounts: [Date: Int]
    var onDayTap: ((Date) -> Void)?

    private let calendar = Calendar.current
    private static let dayLetterFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let isToday = calendar.isDateInToday(day)
                let isPast = calendar.startOfDay(for: day) < calendar.startOfDay(for: Date())

                Button {
                    onDayTap?(day)
                } label: {
                    VStack(spacing: 4) {
                        Text(Self.dayLetterFormatter.string(from: day).prefix(3))
                            .font(.caption2.bold())
                            .foregroundStyle(isToday ? .white : .white.opacity(isPast ? 0.25 : 0.6))

                        // Date number
                        Text("\(calendar.component(.day, from: day))")
                            .font(.caption.bold())
                            .foregroundStyle(isToday ? .white : .white.opacity(isPast ? 0.25 : 0.7))
                            .frame(width: 24, height: 24)
                            .background(isToday ? Color.chooPurple : Color.clear, in: Circle())

                        // Event density dots
                        let count = eventCounts[calendar.startOfDay(for: day)] ?? 0
                        HStack(spacing: 2) {
                            ForEach(0..<min(count, 3), id: \.self) { _ in
                                Circle()
                                    .fill(isPast ? Color.white.opacity(0.15) : Color.chooPurple.opacity(0.6))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(isPast ? 0.6 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
