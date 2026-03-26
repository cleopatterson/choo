import SwiftUI

struct IngredientReviewSheet: View {
    let recipe: Recipe
    let onAdd: ([Ingredient]) -> Void
    let onDismiss: () -> Void

    @State private var selected: Set<Int> = []



    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Text(recipe.icon)
                            .font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(recipe.name)
                                .font(.subheadline.weight(.semibold))
                            Text("What do you need for this week's run?")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.03))
                }

                Section {
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if selected.contains(index) {
                                selected.remove(index)
                            } else {
                                selected.insert(index)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(index) ? Color.chooAmber : .secondary)
                                    .contentTransition(.symbolEffect(.replace))

                                Text(ingredient.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)

                                Spacer()
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.03))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let ingredients = selected.map { recipe.ingredients[$0] }
                        onAdd(ingredients)
                        onDismiss()
                    }
                    .fontWeight(selected.isEmpty ? .regular : .bold)
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
