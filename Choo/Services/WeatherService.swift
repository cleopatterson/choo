import Foundation

@Observable
final class WeatherService {
    private(set) var forecasts: [DayForecast] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var cachedForecasts: [DayForecast] = []
    @ObservationIgnored private var cacheTimestamp: Date?
    private let cacheKey = "WeatherService.cachedForecasts"
    private let cacheTimeKey = "WeatherService.cacheTimestamp"
    private let cacheDuration: TimeInterval = 6 * 60 * 60 // 6 hours

    init() {
        loadCache()
    }

    func fetchForecast() async {
        // Return cached data if still fresh
        if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < cacheDuration, !cachedForecasts.isEmpty {
            forecasts = cachedForecasts
            return
        }

        isLoading = true
        defer { isLoading = false }

        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=-33.75&longitude=151.29"
            + "&daily=temperature_2m_max,weather_code"
            + "&timezone=Australia/Sydney"
            + "&forecast_days=14"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid weather URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")

            var results: [DayForecast] = []
            for i in 0..<response.daily.time.count {
                if let date = dateFormatter.date(from: response.daily.time[i]) {
                    let dayStart = calendar.startOfDay(for: date)
                    results.append(DayForecast(
                        date: dayStart,
                        maxTemp: response.daily.temperature_2m_max[i],
                        weatherCode: response.daily.weather_code[i]
                    ))
                }
            }
            forecasts = results
            cachedForecasts = results
            cacheTimestamp = Date()
            saveCache()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            // Use cached data as fallback
            if !cachedForecasts.isEmpty {
                forecasts = cachedForecasts
            }
        }
    }

    // MARK: - Cache persistence

    private func saveCache() {
        if let data = try? JSONEncoder().encode(cachedForecasts) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
        if let ts = cacheTimestamp {
            UserDefaults.standard.set(ts.timeIntervalSince1970, forKey: cacheTimeKey)
        }
    }

    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([DayForecast].self, from: data) {
            cachedForecasts = decoded
            forecasts = decoded
        }
        let ts = UserDefaults.standard.double(forKey: cacheTimeKey)
        if ts > 0 {
            cacheTimestamp = Date(timeIntervalSince1970: ts)
        }
    }
}

// MARK: - Open-Meteo JSON structure

private struct OpenMeteoResponse: Decodable {
    let daily: DailyData
}

private struct DailyData: Decodable {
    let time: [String]
    let temperature_2m_max: [Double]
    let weather_code: [Int]
}
