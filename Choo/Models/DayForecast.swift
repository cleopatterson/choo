import Foundation

struct DayForecast: Codable, Identifiable {
    var id: Date { date }
    var date: Date
    var maxTemp: Double
    var weatherCode: Int

    var sfSymbol: String {
        switch weatherCode {
        case 0:          return "sun.max.fill"
        case 1, 2:       return "cloud.sun.fill"
        case 3:          return "cloud.fill"
        case 45, 48:     return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57:     return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67:     return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77:         return "cloud.hail.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86:     return "cloud.snow.fill"
        case 95:         return "cloud.bolt.fill"
        case 96, 99:     return "cloud.bolt.rain.fill"
        default:         return "cloud.fill"
        }
    }

    var shortDescription: String {
        switch weatherCode {
        case 0:          return "Clear"
        case 1, 2:       return "Partly cloudy"
        case 3:          return "Overcast"
        case 45, 48:     return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95:         return "Thunderstorm"
        default:         return "Cloudy"
        }
    }
}
