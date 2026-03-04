import SwiftUI

struct RecipeEditView: View {
    let recipe: Recipe?
    let onSave: (String, String, [Ingredient], Int?, Int?, String?, String?, String?, String?) async -> Void
    let onDelete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var ingredients: [Ingredient]
    @State private var newIngredientText = ""
    @State private var showEmojiPicker = false
    @State private var servings: Int
    @State private var prepTimeMinutes: Int
    @State private var selectedCuisine: CuisineType?
    @State private var selectedCarbType: CarbType?
    @State private var selectedPrepEffort: PrepEffort?
    @State private var selectedCalorieDensity: CalorieDensity?
    @FocusState private var ingredientFieldFocused: Bool

    private static let foodEmojis = [
        "🍝", "🍕", "🍔", "🌮", "🫔", "🌯", "🍛", "🍜", "🍲", "🥘",
        "🍗", "🍖", "🥩", "🐟", "🍣", "🦐", "🥗", "🥙", "🧆", "🥚",
        "🍚", "🍱", "🫕", "🥧", "🧀", "🥞", "🍳", "🥓", "🌽", "🥕",
        "🍅", "🥦", "🥑", "🍆", "🫑", "🍠", "🥔", "🍟", "🧇", "🥪",
        "🌶️", "🫘", "🥫", "🍽️", "🥡", "🥟", "🍤", "🥮", "🍰", "🎂",
    ]

    init(
        recipe: Recipe?,
        onSave: @escaping (String, String, [Ingredient], Int?, Int?, String?, String?, String?, String?) async -> Void,
        onDelete: (() async -> Void)? = nil
    ) {
        self.recipe = recipe
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: recipe?.name ?? "")
        _icon = State(initialValue: recipe?.icon ?? "🍽️")
        _ingredients = State(initialValue: recipe?.ingredients ?? [])
        _servings = State(initialValue: recipe?.servings ?? 4)
        _prepTimeMinutes = State(initialValue: recipe?.prepTimeMinutes ?? 0)
        _selectedCuisine = State(initialValue: recipe?.cuisineType)
        _selectedCarbType = State(initialValue: recipe?.carbTypeEnum)
        _selectedPrepEffort = State(initialValue: recipe?.prepEffortEnum)
        _selectedCalorieDensity = State(initialValue: recipe?.calorieDensityEnum)
    }

    private var isCreate: Bool { recipe == nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                recipeSection
                metadataSection
                ingredientsSection
                if !isCreate, let onDelete, recipe?.isDefault != true {
                    deleteSection(onDelete)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(isCreate ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(
                                name, icon, ingredients,
                                servings > 0 ? servings : nil,
                                prepTimeMinutes > 0 ? prepTimeMinutes : nil,
                                selectedCuisine?.rawValue,
                                selectedCarbType?.rawValue,
                                selectedPrepEffort?.rawValue,
                                selectedCalorieDensity?.rawValue
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Sections

    private var recipeSection: some View {
        Section("Recipe") {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showEmojiPicker.toggle()
                    }
                } label: {
                    Text(icon)
                        .font(.system(size: 40))
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                TextField("Recipe name", text: $name)
                    .font(.headline)
            }

            if showEmojiPicker {
                emojiPicker
            }
        }
    }

    private var metadataSection: some View {
        Section("Details") {
            HStack {
                Text("Prep time")
                Spacer()
                Stepper("\(prepTimeMinutes) min", value: $prepTimeMinutes, in: 0...480, step: 5)
                    .fixedSize()
            }

            HStack {
                Text("Serves")
                Spacer()
                Stepper("\(servings)", value: $servings, in: 1...12)
                    .fixedSize()
            }

            Picker("Cuisine", selection: $selectedCuisine) {
                Text("Not set").tag(CuisineType?.none)
                ForEach(CuisineType.allCases) { cuisine in
                    Text(cuisine.displayName).tag(CuisineType?.some(cuisine))
                }
            }

            Picker("Carb", selection: $selectedCarbType) {
                Text("Not set").tag(CarbType?.none)
                ForEach(CarbType.allCases) { carb in
                    Text(carb.displayName).tag(CarbType?.some(carb))
                }
            }

            Picker("Effort", selection: $selectedPrepEffort) {
                Text("Not set").tag(PrepEffort?.none)
                ForEach(PrepEffort.allCases) { effort in
                    Text(effort.displayName).tag(PrepEffort?.some(effort))
                }
            }

            Picker("Richness", selection: $selectedCalorieDensity) {
                Text("Not set").tag(CalorieDensity?.none)
                ForEach(CalorieDensity.allCases) { density in
                    Text(density.displayName).tag(CalorieDensity?.some(density))
                }
            }
        }
    }

    private var emojiPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 8) {
            ForEach(Self.foodEmojis, id: \.self) { emoji in
                Button {
                    icon = emoji
                    withAnimation(.spring(duration: 0.3)) {
                        showEmojiPicker = false
                    }
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            icon == emoji
                                ? RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.15))
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                HStack {
                    Text(ingredient.name)
                    if let qty = ingredient.quantity {
                        Spacer()
                        Text(qty)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indices in
                ingredients.remove(atOffsets: indices)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green.opacity(0.7))

                TextField("Add ingredient…", text: $newIngredientText)
                    .focused($ingredientFieldFocused)
                    .onSubmit { addIngredient() }
                    .submitLabel(.done)
            }
        }
    }

    private func deleteSection(_ action: @escaping () async -> Void) -> some View {
        Section {
            Button(role: .destructive) {
                Task {
                    await action()
                    dismiss()
                }
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Recipe", systemImage: "trash")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func addIngredient() {
        let text = newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        ingredients.append(Ingredient(name: text))
        newIngredientText = ""
        ingredientFieldFocused = true
    }
}
