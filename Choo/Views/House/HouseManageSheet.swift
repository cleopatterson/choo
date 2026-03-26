import SwiftUI

struct HouseManageSheet: View {
    @Bindable var viewModel: HouseViewModel
    @Environment(\.dismiss) private var dismiss

    var initialMode: Mode = .choose
    @State private var mode: Mode = .choose
    @State private var didSetInitialMode = false
    @State private var categoryName = ""
    @State private var categoryEmoji = "\u{1F9F9}"
    @State private var categoryColor = "#C88EA7"
    @State private var selectedCategory: ChoreCategory?
    @State private var showingTypeForm = false

    @State private var categoryToDelete: ChoreCategory?
    @State private var editingCategory: ChoreCategory?
    @State private var editCategoryName = ""
    @State private var editCategoryEmoji = ""

    enum Mode {
        case choose
        case addCategory
        case manageCategories
        case editCategory
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch mode {
                case .choose:
                    chooseStep
                case .addCategory:
                    addCategoryStep
                case .manageCategories:
                    manageCategoriesStep
                case .editCategory:
                    editCategoryStep
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle({
                switch mode {
                case .choose: return "Add"
                case .addCategory: return "New Category"
                case .manageCategories: return "Manage Categories"
                case .editCategory: return "Edit Category"
                }
            }())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if !didSetInitialMode {
                mode = initialMode
                didSetInitialMode = true
            }
        }
        .sheet(isPresented: $showingTypeForm) {
            if let category = selectedCategory {
                HouseChoreTypeFormSheet(category: category) { name, description, duration, frequency in
                    await viewModel.addChoreType(
                        to: category,
                        name: name,
                        description: description,
                        durationMinutes: duration,
                        frequency: frequency
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
                            .foregroundStyle(Color.chooRose)

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

                // Manage categories
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .manageCategories
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(Color.chooRose)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Categories")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Reorder or delete chore categories")
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
                    .foregroundStyle(Color.chooRose)
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
                            .background(Color.chooRose.opacity(categoryName.isEmpty ? 0.3 : 1), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .disabled(categoryName.isEmpty)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
    }

    // MARK: - Manage Categories

    private var manageCategoriesStep: some View {
        VStack(spacing: 0) {
            HStack {
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
                    .foregroundStyle(Color.chooRose)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                ForEach(viewModel.categories) { category in
                    Button {
                        editingCategory = category
                        editCategoryName = category.name
                        editCategoryEmoji = category.emoji
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = .editCategory
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(category.emoji)
                                .font(.title3)
                                .frame(width: 32, height: 32)
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
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
                .onMove { from, to in
                    viewModel.reorderCategories(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    if let index = offsets.first {
                        categoryToDelete = viewModel.categories[index]
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
        }
        .confirmationDialog(
            "Delete \(categoryToDelete?.name ?? "category")?",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let cat = categoryToDelete {
                    Task {
                        await viewModel.deleteCategory(cat)
                        categoryToDelete = nil
                    }
                }
            }
        } message: {
            if let cat = categoryToDelete {
                let typeCount = cat.choreTypes.count
                let dueInCategory = viewModel.allItems.filter { $0.categoryName == cat.name && $0.isDue }.count
                let overdueInCategory = viewModel.allItems.filter { $0.categoryName == cat.name && $0.isOverdue }.count
                if dueInCategory > 0 || overdueInCategory > 0 {
                    Text("This will remove \(typeCount) chore type\(typeCount == 1 ? "" : "s"), including \(dueInCategory) due and \(overdueInCategory) overdue.")
                } else {
                    Text("This will remove \(typeCount) chore type\(typeCount == 1 ? "" : "s").")
                }
            }
        }
    }

    // MARK: - Edit Category

    private var editCategoryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .manageCategories
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.chooRose)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Category Name")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    TextField("Name", text: $editCategoryName)
                        .glassField()

                    Text("Emoji")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    TextField("Emoji", text: $editCategoryEmoji)
                        .glassField()

                    Button {
                        guard !editCategoryName.isEmpty, let cat = editingCategory else { return }
                        Task {
                            await viewModel.updateCategory(
                                cat,
                                name: editCategoryName,
                                emoji: editCategoryEmoji.isEmpty ? cat.emoji : editCategoryEmoji
                            )
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = .manageCategories
                            }
                        }
                    } label: {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.chooRose.opacity(editCategoryName.isEmpty ? 0.3 : 1), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .disabled(editCategoryName.isEmpty)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
    }
}
