import SwiftUI

struct HouseHeroView: View {
    @Bindable var viewModel: HouseViewModel

    var body: some View {
        let due = viewModel.dueItems
        if due.isEmpty {
            HeroCardView(
                label: "STATUS",
                title: "",
                subtitle: "",
                emoji: "",
                accent: .house,
                isEmpty: true,
                emptyMessage: "All caught up",
                emptyEmoji: "\u{2728}"
            ) { EmptyView() }
        } else {
            filledHero(due: due)
        }
    }

    @ViewBuilder
    private func filledHero(due: [HouseViewModel.HouseDueItem]) -> some View {
        let overdue = due.filter(\.isOverdue)
        let topItems = overdue.isEmpty ? Array(due.prefix(3)) : Array(overdue.prefix(3))

        let title: String = {
            let names = topItems.map(\.choreType.name)
            if names.count == 1 { return names[0] }
            if names.count == 2 { return "\(names[0]) & \(names[1])" }
            return "\(names[0]) + \(names.count - 1) more"
        }()

        let subtitle: String = {
            if !overdue.isEmpty {
                return "\(overdue.count) overdue \u{00B7} \(due.count) total due"
            }
            return "\(due.count) chore\(due.count == 1 ? "" : "s") due"
        }()

        let emoji: String = {
            let uniqueEmojis = topItems.map(\.categoryEmoji)
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            return uniqueEmojis.joined()
        }()

        let emojiSize: CGFloat = emoji.count > 1 ? 30 : 42

        let label: String = overdue.isEmpty ? "DUE NOW" : "OVERDUE"

        HeroCardView(
            label: label,
            title: title,
            subtitle: subtitle,
            emoji: emoji,
            accent: .house,
            emojiSize: emojiSize
        ) {
            // Frequency pills
            let frequencies = topItems.map(\.choreType.effectiveFrequency)
                .reduce(into: [ChoreFrequency]()) { if !$0.contains($1) { $0.append($1) } }
            ForEach(frequencies) { freq in
                HeroCardView<EmptyView>.coloredPill(
                    text: freq.displayName,
                    color: Color.chooRose
                )
            }

            // Category pills
            let cats = topItems
                .reduce(into: [(name: String, color: String)]()) { result, item in
                    if !result.contains(where: { $0.name == item.categoryName }) {
                        result.append((name: item.categoryName, color: item.categoryColorHex))
                    }
                }
            ForEach(cats, id: \.name) { cat in
                HeroCardView<EmptyView>.coloredPill(
                    text: cat.name,
                    color: Color(hex: cat.color)
                )
            }
        }
    }
}
