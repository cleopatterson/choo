import SwiftUI

struct SupplyAddSheet: View {
    @Bindable var viewModel: SuppliesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: SupplyCategory?

    var body: some View {
        if let category = selectedCategory {
            // Step 2: Form (provides its own NavigationStack)
            NavigationStack {
                SupplyItemFormSheet(
                    category: category,
                    existingItem: nil,
                    onSave: { name, cat, cadence, aisleOrder in
                        Task {
                            await viewModel.addItem(
                                name: name,
                                category: cat,
                                cadence: cadence,
                                aisleOrder: aisleOrder
                            )
                        }
                        dismiss()
                    },
                    onDelete: nil
                )
            }
        } else {
            // Step 1: Pick category
            NavigationStack {
                categoryStep
                    .background(.ultraThinMaterial)
                    .navigationTitle("Add")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
            }
        }
    }

    // MARK: - Category Picker

    private var categoryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("ADD TO CATEGORY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(1)
                    .padding(.horizontal)

                VStack(spacing: 6) {
                    ForEach(SupplyCategory.allCases, id: \.self) { category in
                        categoryRow(category)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedCategory = category
                            }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func categoryRow(_ category: SupplyCategory) -> some View {
        let items = viewModel.firestoreService.supplies.filter { $0.category == category }

        return HStack(spacing: 12) {
            Text(category.emoji)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color.chooAmber.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
}
