import SwiftUI

struct RecipePickerView: View {
    @Bindable var viewModel: DinnerPlannerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var editingRecipe: Recipe?
    @State private var isCreatingNew = false

    private var filteredRecipes: [Recipe] {
        let recipes = viewModel.firestoreService.recipes
        if searchText.trimmed.isEmpty {
            return recipes
        }
        let query = searchText.lowercased()
        return recipes.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14),
                    ],
                    spacing: 14
                ) {
                    ForEach(filteredRecipes) { recipe in
                        recipeCard(recipe)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if isEditing {
                                    editingRecipe = recipe
                                } else {
                                    guard let dayIndex = viewModel.selectedDayIndex else { return }
                                    Task {
                                        await viewModel.assignRecipe(recipe, toDayIndex: dayIndex)
                                    }
                                    dismiss()
                                }
                            }
                    }

                    addNewCard
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            isCreatingNew = true
                        }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationTitle("Pick a Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.selectedDayIndex = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
            }
            .sheet(item: $editingRecipe) { recipe in
                RecipeEditView(
                    recipe: recipe,
                    onSave: { name, icon, ingredients, servings, prepTime, cuisine, carbType, prepEffort, calorieDensity in
                        var updated = recipe
                        updated.name = name
                        updated.icon = icon
                        updated.ingredients = ingredients
                        updated.servings = servings
                        updated.prepTimeMinutes = prepTime
                        updated.cuisine = cuisine
                        updated.carbType = carbType
                        updated.prepEffort = prepEffort
                        updated.calorieDensity = calorieDensity
                        try? await viewModel.firestoreService.updateRecipe(
                            familyId: viewModel.familyId,
                            recipe: updated
                        )
                    },
                    onDelete: recipe.isDefault ? nil : {
                        if let id = recipe.id {
                            try? await viewModel.firestoreService.deleteRecipe(
                                familyId: viewModel.familyId,
                                recipeId: id
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $isCreatingNew) {
                RecipeEditView(
                    recipe: nil,
                    onSave: { name, icon, ingredients, servings, prepTime, cuisine, carbType, prepEffort, calorieDensity in
                        let newRecipe = Recipe(
                            name: name,
                            icon: icon,
                            ingredients: ingredients,
                            isDefault: false,
                            servings: servings,
                            prepTimeMinutes: prepTime,
                            cuisine: cuisine,
                            carbType: carbType,
                            prepEffort: prepEffort,
                            calorieDensity: calorieDensity
                        )
                        _ = try? await viewModel.firestoreService.addRecipe(
                            familyId: viewModel.familyId,
                            recipe: newRecipe
                        )
                    }
                )
            }
        }
    }

    // MARK: - Recipe Card

    private func recipeCard(_ recipe: Recipe) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Text(recipe.icon)
                    .font(.system(size: 56))
                    .frame(height: 64)
                    .frame(maxWidth: .infinity)

                if isEditing {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(recipe.name)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            Text("\(recipe.ingredients.count) items")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .overlay(alignment: .top) {
            if viewModel.lastWeekRecipeIds.contains(recipe.id ?? "") {
                Text("Last wk")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.1), in: Capsule())
                    .padding(.top, 8)
            }
        }
        .background(
            ZStack {
                Text(recipe.icon)
                    .font(.system(size: 120))
                    .blur(radius: 30)
                    .opacity(0.3)

                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Add New Card

    private var addNewCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
                .frame(height: 64)

            Text("Add New")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }
}
