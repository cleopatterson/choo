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

    @ViewBuilder
    private var filledHero: some View {
        let sessions = todaySessions
        let nextSession = viewModel.todayNextSession

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

        // Combined subtitle: "Morning + Lunch · 1hr 30min"
        let combinedSubtitle: String = {
            let slots = sessions.map(\.timeSlot.label)
            let slotText = slots.joined(separator: " + ")
            let totalMinutes = sessions.compactMap(\.assignment.durationMinutes).reduce(0, +)
            if totalMinutes > 0 {
                let durText: String
                if totalMinutes >= 60 {
                    let hrs = totalMinutes / 60
                    let mins = totalMinutes % 60
                    durText = mins > 0 ? "\(hrs)hr \(mins)min" : "\(hrs)hr"
                } else {
                    durText = "\(totalMinutes)min"
                }
                return "\(slotText) · \(durText)"
            }
            return slotText
        }()

        // Combined emoji: single or pair
        let combinedEmoji: String = {
            let uniqueEmojis = sessions.map(\.assignment.categoryEmoji)
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            return uniqueEmojis.joined()
        }()

        let emojiSize: CGFloat = combinedEmoji.count > 1 ? 30 : 42

        // Label
        let label: String = {
            if let next = nextSession {
                return "UP NEXT · THIS \(next.timeSlot.label.uppercased())"
            }
            return "TODAY"
        }()

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
        // Category pills (one per unique category, colored)
        let uniqueCategories = sessions.map(\.assignment)
            .reduce(into: [(name: String, color: String)]()) { result, assignment in
                if !result.contains(where: { $0.name == assignment.categoryName }) {
                    result.append((name: assignment.categoryName, color: assignment.categoryColorHex))
                }
            }

        ForEach(uniqueCategories, id: \.name) { cat in
            HeroCardView<EmptyView>.coloredPill(
                text: cat.name,
                color: Color(hex: cat.color)
            )
        }

        // Calories pill (combined total)
        let totalCalories = sessions.compactMap(\.assignment.estimatedCalories).reduce(0, +)
        if totalCalories > 0 {
            HeroCardView<EmptyView>.coloredPill(
                text: "~\(totalCalories) cal",
                color: calorieColor(totalCalories)
            )
        }

        // ⚡ Day load pill
        if totalCalories > 0 {
            let load = DayLoad.from(totalCalories: totalCalories)
            HeroCardView<EmptyView>.coloredPill(
                text: "⚡ \(load.displayName)",
                color: dayLoadColor(load)
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

    private func dayLoadColor(_ load: DayLoad) -> Color {
        switch load {
        case .light: Color(red: 0.0, green: 0.72, blue: 0.58)      // green
        case .moderate: Color(red: 0.99, green: 0.80, blue: 0.43)  // yellow
        case .high: Color(red: 0.95, green: 0.57, blue: 0.24)      // orange
        case .peak: Color(red: 1.0, green: 0.42, blue: 0.42)       // red
        }
    }
}
