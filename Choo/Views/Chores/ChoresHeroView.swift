import SwiftUI

struct ChoresHeroView: View {
    @Bindable var viewModel: ChoresViewModel

    private var todayChores: [ChoreSlotAssignment] {
        viewModel.todayChores
    }

    var body: some View {
        if !todayChores.isEmpty {
            filledHero
        } else {
            HeroCardView(
                label: "TODAY",
                title: "",
                subtitle: "",
                emoji: "",
                accent: .chores,
                isEmpty: true,
                emptyMessage: "Day off",
                emptyEmoji: "\u{1F60E}"
            ) { EmptyView() }
        }
    }

    // MARK: - Filled Hero

    @ViewBuilder
    private var filledHero: some View {
        let chores = todayChores
        let nextChore = viewModel.todayNextChore

        let combinedTitle: String = {
            let incomplete = chores.filter { !$0.isCompleted }
            let names = incomplete.isEmpty ? chores.map(\.choreTypeName) : incomplete.map(\.choreTypeName)
            if names.count == 1 {
                return names[0]
            }
            if names.count == 2 {
                return "\(names[0]) & \(names[1])"
            }
            return "\(names[0]) + \(names.count - 1) more"
        }()

        let combinedSubtitle: String = {
            let totalMinutes = chores.compactMap(\.durationMinutes).reduce(0, +)
            let doneCount = chores.filter(\.isCompleted).count
            var parts: [String] = []
            if totalMinutes > 0 {
                let durText: String
                if totalMinutes >= 60 {
                    let hrs = totalMinutes / 60
                    let mins = totalMinutes % 60
                    durText = mins > 0 ? "\(hrs)hr \(mins)min" : "\(hrs)hr"
                } else {
                    durText = "\(totalMinutes)min"
                }
                parts.append(durText)
            }
            if doneCount > 0 {
                parts.append("\(doneCount)/\(chores.count) done")
            } else {
                parts.append("\(chores.count) chore\(chores.count == 1 ? "" : "s")")
            }
            return parts.joined(separator: " \u{00B7} ")
        }()

        let combinedEmoji: String = {
            let uniqueEmojis = chores.map(\.categoryEmoji)
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            return uniqueEmojis.joined()
        }()

        let emojiSize: CGFloat = combinedEmoji.count > 1 ? 30 : 42

        let label: String = {
            if let next = nextChore, !next.isCompleted {
                let name = viewModel.assignee(for: next.assignedTo)?.displayName.uppercased() ?? ""
                return "UP NEXT \u{00B7} \(name)"
            }
            return "TODAY"
        }()

        HeroCardView(
            label: label,
            title: combinedTitle,
            subtitle: combinedSubtitle,
            emoji: combinedEmoji,
            accent: .chores,
            emojiSize: emojiSize
        ) {
            choresPills(for: chores)
        }
    }

    // MARK: - Pills

    @ViewBuilder
    private func choresPills(for chores: [ChoreSlotAssignment]) -> some View {
        let uniqueCategories = chores
            .reduce(into: [(name: String, color: String)]()) { result, chore in
                if !result.contains(where: { $0.name == chore.categoryName }) {
                    result.append((name: chore.categoryName, color: chore.categoryColorHex))
                }
            }

        ForEach(uniqueCategories, id: \.name) { cat in
            HeroCardView<EmptyView>.coloredPill(
                text: cat.name,
                color: Color(hex: cat.color)
            )
        }

        // Person pills
        let uniqueAssigneeIds = chores
            .reduce(into: [String]()) { result, chore in
                if !result.contains(chore.assignedTo) {
                    result.append(chore.assignedTo)
                }
            }

        ForEach(uniqueAssigneeIds, id: \.self) { assigneeId in
            if let person = viewModel.assignee(for: assigneeId) {
                HeroCardView<EmptyView>.coloredPill(
                    text: "\(person.emoji) \(person.displayName)",
                    color: Color(hex: person.colorHex)
                )
            }
        }
    }
}
