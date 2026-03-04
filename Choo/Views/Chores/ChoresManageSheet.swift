import SwiftUI

struct ChoresManageSheet: View {
    @Bindable var viewModel: ChoresViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .choose
    @State private var categoryName = ""
    @State private var categoryEmoji = "\u{1F9F9}"
    @State private var categoryColor = "#f97066"
    @State private var selectedCategory: ChoreCategory?
    @State private var showingTypeForm = false

    private enum Mode {
        case choose
        case addCategory
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch mode {
                case .choose:
                    chooseStep
                case .addCategory:
                    addCategoryStep
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle(mode == .choose ? "Add" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingTypeForm) {
            if let category = selectedCategory {
                ChoreTypeFormSheet(category: category) { name, description, duration in
                    await viewModel.addChoreType(
                        to: category,
                        name: name,
                        description: description,
                        durationMinutes: duration
                    )
                    dismiss()
                }
            }
        }
    }

    // MARK: - Choose Step

    private var chooseStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .addCategory
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(Color.chooCoral)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Category")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Add a new chore category like Garage, Garden, etc.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ADD TYPE TO CATEGORY")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)
                        .padding(.top, 8)

                    ForEach(viewModel.categories) { category in
                        Button {
                            selectedCategory = category
                            showingTypeForm = true
                        } label: {
                            HStack(spacing: 12) {
                                Text(category.emoji)
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: category.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(category.choreTypes.count) type\(category.choreTypes.count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Add Category

    private var addCategoryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .choose
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.chooCoral)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Category Name")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    TextField("e.g. Garage", text: $categoryName)
                        .glassField()

                    Text("Emoji")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    TextField("e.g. \u{1F6E0}\u{FE0F}", text: $categoryEmoji)
                        .glassField()

                    Button {
                        guard !categoryName.isEmpty else { return }
                        Task {
                            await viewModel.addCategory(
                                name: categoryName,
                                emoji: categoryEmoji.isEmpty ? "\u{1F9F9}" : categoryEmoji,
                                colorHex: categoryColor
                            )
                            dismiss()
                        }
                    } label: {
                        Text("Add Category")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.chooCoral.opacity(categoryName.isEmpty ? 0.3 : 1), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .disabled(categoryName.isEmpty)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
    }
}
