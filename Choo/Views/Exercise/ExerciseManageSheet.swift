import SwiftUI

struct ExerciseManageSheet: View {
    @Bindable var viewModel: ExerciseViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .choose
    @State private var categoryName = ""
    @State private var categoryEmoji = "💪"
    @State private var categoryColor = "#4ecdc4"
    @State private var selectedCategory: ExerciseCategory?
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
                SessionTypeFormSheet(category: category) { name, description, duration, calories, intensity in
                    await viewModel.addSessionType(
                        to: category,
                        name: name,
                        description: description,
                        durationMinutes: duration,
                        estimatedCalories: calories,
                        intensity: intensity
                    )
                    dismiss()
                }
            }
        }
    }

    // MARK: - Step 1: Choose what to add

    private var chooseStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Add category option
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .addCategory
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(Color(hex: "#4ecdc4"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Category")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Add a new exercise category like Cycling, Dance, etc.")
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

                // Add type to existing category
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
                                    Text("\(category.sessionTypes.count) type\(category.sessionTypes.count == 1 ? "" : "s")")
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
                    .foregroundStyle(Color(hex: "#4ecdc4"))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Category Name")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    TextField("e.g. Cycling", text: $categoryName)
                        .glassField()

                    Text("Emoji")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    TextField("e.g. 🚴", text: $categoryEmoji)
                        .glassField()

                    Button {
                        guard !categoryName.isEmpty else { return }
                        Task {
                            await viewModel.addCategory(
                                name: categoryName,
                                emoji: categoryEmoji.isEmpty ? "💪" : categoryEmoji,
                                colorHex: categoryColor
                            )
                            dismiss()
                        }
                    } label: {
                        Text("Add Category")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#4ecdc4").opacity(categoryName.isEmpty ? 0.3 : 1), in: RoundedRectangle(cornerRadius: 12))
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
