import SwiftUI

/// This week's dinners as a set of meals with no night attached — built to be
/// glanced at while you walk the supermarket aisles.
///
/// Tap any meal to open the pick list. Hold one to drop it from the week.
struct DinnerPicksView: View {
    @Bindable var viewModel: DinnerPlannerViewModel
    @Binding var showingPicker: Bool

    /// Recipe id currently being held down, on its way to being removed.
    @State private var holdingId: String?

    private static let cardBackground = Color.white.opacity(0.06)
    private static let cardBorder = Color.white.opacity(0.09)
    private static let chipBackground = Color.white.opacity(0.07)
    private static let removeBackground = Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.18)
    private static let removeBorder = Color(red: 0.973, green: 0.443, blue: 0.443).opacity(0.5)
    private static let removeChip = Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.20)
    private static let removeText = Color(red: 0.988, green: 0.647, blue: 0.647).opacity(0.9)

    /// Pairs for the grid. An odd number leaves the last meal on its own row.
    private var pickRows: [[MealAssignment]] {
        var rows: [[MealAssignment]] = []
        var index = 0
        let all = viewModel.picks
        while index < all.count {
            if index == all.count - 1 {
                rows.append([all[index]])       // last one, full width
                index += 1
            } else {
                rows.append([all[index], all[index + 1]])
                index += 2
            }
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("This week's dinners")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .padding(.bottom, 4)

            Text(viewModel.contextLabel)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 14)

            if viewModel.picks.isEmpty {
                emptyCard
            } else {
                VStack(spacing: 9) {
                    ForEach(Array(pickRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 9) {
                            ForEach(row, id: \.recipeId) { meal in
                                pickTile(meal, isWide: row.count == 1)
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.picks.count)
    }

    // MARK: - Empty state

    private var emptyCard: some View {
        VStack(spacing: 3) {
            Text("Nothing picked yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text("Tap to choose this week's meals")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingPicker = true
        }
    }

    // MARK: - Meal tile

    @ViewBuilder
    private func pickTile(_ meal: MealAssignment, isWide: Bool) -> some View {
        let holding = holdingId == meal.recipeId
        let recipe = viewModel.recipe(for: meal)

        Group {
            if isWide {
                HStack(alignment: .center, spacing: 12) {
                    iconChip(meal.recipeIcon, holding: holding)
                    tileText(meal, recipe: recipe, holding: holding)
                }
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    iconChip(meal.recipeIcon, holding: holding)
                    tileText(meal, recipe: recipe, holding: holding)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(holding ? Self.removeBackground : Self.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(holding ? Self.removeBorder : Self.cardBorder, lineWidth: 1)
        )
        .scaleEffect(holding ? 0.96 : 1)
        .animation(.easeOut(duration: 0.25), value: holding)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingPicker = true
        }
        .onLongPressGesture(minimumDuration: 0.65) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            holdingId = nil
            Task { await viewModel.removePick(recipeId: meal.recipeId) }
        } onPressingChanged: { pressing in
            holdingId = pressing ? meal.recipeId : nil
        }
    }

    private func iconChip(_ emoji: String, holding: Bool) -> some View {
        Text(emoji)
            .font(.system(size: 17))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(holding ? Self.removeChip : Self.chipBackground)
            )
    }

    private func tileText(_ meal: MealAssignment, recipe: Recipe?, holding: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(meal.recipeName)
                .font(.system(size: 15, weight: .semibold))
                .lineSpacing(1)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(holding ? "keep holding to remove…" : (recipe?.prepTimeDisplay ?? ""))
                .font(.system(size: 11))
                .foregroundStyle(holding ? Self.removeText : .white.opacity(0.4))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pick list

/// Full-screen "Pick this week" list — tick the meals you want, with when you
/// last had each one.
struct DinnerPickSheet: View {
    @Bindable var viewModel: DinnerPlannerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var creatingRecipe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    Text("YOUR MEALS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.vertical, 8)

                    ForEach(viewModel.libraryRecipes) { recipe in
                        libraryRow(recipe)
                    }

                    addMealRow
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .chooBackground()
        .sheet(isPresented: $creatingRecipe) {
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
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pick this week")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text(viewModel.pickCountLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.chooAmber.opacity(0.92), in: Capsule())
                    .foregroundStyle(Color(red: 0.102, green: 0.063, blue: 0.020))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private func libraryRow(_ recipe: Recipe) -> some View {
        let picked = viewModel.isPicked(recipe)
        let staleLook = viewModel.hadItLastWeek(recipe)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(picked ? Color.chooAmber.opacity(0.9) : .clear)
                Circle()
                    .strokeBorder(picked ? Color.chooAmber.opacity(0.9) : .white.opacity(0.28), lineWidth: 1.5)
                if picked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.102, green: 0.063, blue: 0.020))
                }
            }
            .frame(width: 22, height: 22)

            Text(recipe.icon)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 11).fill(.white.opacity(0.06)))

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(viewModel.librarySubtitle(for: recipe))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(staleLook ? 0.32 : 0.45))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(picked ? Color.chooAmber.opacity(0.14) : .white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(picked ? Color.chooAmber.opacity(0.36) : .white.opacity(0.09), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await viewModel.togglePick(recipe) }
        }
    }

    private var addMealRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.chooAmber.opacity(0.9))
            Text("Add a meal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            creatingRecipe = true
        }
    }
}
