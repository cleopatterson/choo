import SwiftUI

struct ExerciseHeroView: View {
    @Bindable var viewModel: ExerciseViewModel

    private var todaySessions: [(timeSlot: TimeSlot, assignment: ExerciseSlotAssignment)] {
        guard let idx = viewModel.todayIndex else { return [] }
        return viewModel.sessionsForDay(idx)
    }

    var body: some View {
        if !todaySessions.isEmpty {
            filledHero
        } else if viewModel.isTodayRestDay {
            HeroCardView(
                label: "TODAY",
                title: "",
                subtitle: "",
                emoji: "",
                accent: .exercise,
                isEmpty: true,
                emptyMessage: "Rest day",
                emptyEmoji: "😴"
            ) { EmptyView() }
        } else {
            HeroCardView(
                label: "TODAY",
                title: "",
                subtitle: "",
                emoji: "",
                accent: .exercise,
                isEmpty: true,
                emptyMessage: "Nothing planned"
            ) { EmptyView() }
        }
    }

    // MARK: - Filled Hero (sessions today)

    private static let heroDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    @ViewBuilder
    private var filledHero: some View {
        let sessions = todaySessions

        // Combined title: "Yin Yoga & Easy Run"
        let combinedTitle: String = {
            if sessions.count == 1 {
                return sessions[0].assignment.sessionTypeName
            }
            let names = sessions.map(\.assignment.sessionTypeName)
            if names.count == 2 {
                return "\(names[0]) & \(names[1])"
            }
            return names.dropLast().joined(separator: ", ") + " & " + (names.last ?? "")
        }()

        // Subtitle: total duration
        let totalMinutes = sessions.compactMap(\.assignment.durationMinutes).reduce(0, +)
        let combinedSubtitle: String = {
            if totalMinutes > 0 {
                if totalMinutes >= 60 {
                    let hrs = totalMinutes / 60
                    let mins = totalMinutes % 60
                    return mins > 0 ? "\(hrs)hr \(mins)min" : "\(hrs)hr"
                }
                return "\(totalMinutes) min"
            }
            return ""
        }()

        // Combined emoji: single or pair
        let combinedEmoji: String = {
            let uniqueEmojis = sessions.map(\.assignment.categoryEmoji)
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            return uniqueEmojis.joined()
        }()

        let emojiSize: CGFloat = combinedEmoji.count > 1 ? 30 : 42

        let label = "TODAY · \(Self.heroDateFormatter.string(from: Date()).uppercased())"

        HeroCardView(
            label: label,
            title: combinedTitle,
            subtitle: combinedSubtitle,
            emoji: combinedEmoji,
            accent: .exercise,
            emojiSize: emojiSize
        ) {
            exercisePills(for: sessions)
        }
    }

    // MARK: - Exercise Pills

    @ViewBuilder
    private func exercisePills(for sessions: [(timeSlot: TimeSlot, assignment: ExerciseSlotAssignment)]) -> some View {
        // Calories pill (combined total)
        let totalCalories = sessions.compactMap(\.assignment.estimatedCalories).reduce(0, +)
        if totalCalories > 0 {
            HeroCardView<EmptyView>.coloredPill(
                text: "~\(totalCalories) cal",
                color: calorieColor(totalCalories)
            )
        }

        // Intensity pill (highest across sessions)
        let allCases = ExerciseIntensity.allCases
        let intensities = sessions.compactMap(\.assignment.intensityEnum)
        if let highest = intensities.max(by: { (allCases.firstIndex(of: $0) ?? 0) < (allCases.firstIndex(of: $1) ?? 0) }) {
            HeroCardView<EmptyView>.coloredPill(
                text: highest.displayName,
                color: intensityColor(highest)
            )
        }
    }

    // MARK: - Color Helpers

    private func calorieColor(_ calories: Int) -> Color {
        switch calories {
        case ..<300: Color(red: 0.0, green: 0.72, blue: 0.58)      // green
        case 300..<500: Color(red: 0.95, green: 0.57, blue: 0.24)  // amber
        default: Color(red: 1.0, green: 0.42, blue: 0.42)          // red
        }
    }

    private func intensityColor(_ intensity: ExerciseIntensity) -> Color {
        switch intensity {
        case .light: Color(red: 0.0, green: 0.72, blue: 0.58)      // green
        case .moderate: Color(red: 0.99, green: 0.80, blue: 0.43)  // yellow
        case .high: Color(red: 0.95, green: 0.57, blue: 0.24)      // orange
        case .peak: Color(red: 1.0, green: 0.42, blue: 0.42)       // red
        }
    }
}
