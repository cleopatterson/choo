import SwiftUI

struct WeatherStripView: View {
    let forecasts: [DayForecast]
    let weekDays: [Date]
    var showHeading: Bool = true

    private let calendar = Calendar.current

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        if forecasts.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                if showHeading {
                    HStack {
                        Text("WEATHER")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1.5)
                        Spacer()
                        Text("Sydney")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 20)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(forecastsForWeek()) { forecast in
                            let isPast = calendar.startOfDay(for: forecast.date) < calendar.startOfDay(for: Date())
                            let isToday = calendar.isDateInToday(forecast.date)

                            VStack(spacing: 4) {
                                Text(isToday ? "Today" : Self.dayFormatter.string(from: forecast.date))
                                    .font(.caption2.bold())
                                    .foregroundStyle(isToday ? .white : isPast ? .white.opacity(0.35) : .white.opacity(0.6))

                                Image(systemName: forecast.sfSymbol)
                                    .font(.title3)
                                    .symbolRenderingMode(.multicolor)
                                    .opacity(isPast ? 0.35 : 1)

                                Text("\(Int(forecast.maxTemp))°")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(isPast ? .white.opacity(0.35) : .white)
                            }
                            .frame(minWidth: 44)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        )
    }

    private func forecastsForWeek() -> [DayForecast] {
        weekDays.compactMap { day in
            let dayStart = calendar.startOfDay(for: day)
            return forecasts.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
        }
    }
}
