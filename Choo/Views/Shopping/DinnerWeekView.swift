import SwiftUI

/// The whole week of dinners as a tile mosaic.
///
/// Browsing: seven night tiles, all visible at once. Tapping a night opens the
/// recipe picker for that night, exactly as before.
/// Plan mode: the mosaic stays put and a pool of meals surfaces underneath —
/// tap a meal then a night, or drag a meal onto a night.
struct DinnerWeekView: View {
    @Bindable var viewModel: DinnerPlannerViewModel
    @Binding var planMode: Bool

    @State private var pickedRecipeId: String?
    @State private var dayToClear: ClearDay?

    private struct ClearDay: Identifiable {
        let id: Int
    }

    // MARK: - Palette (matches the Choo design system)

    private static let mealBackground = Color.chooAmber.opacity(0.20)
    private static let mealBorder = Color.chooAmber.opacity(0.34)
    private static let emptyBackground = Color.white.opacity(0.03)
    private static let emptyBorder = Color.white.opacity(0.10)
    private static let armedBackground = Color.chooAmber.opacity(0.10)
    private static let armedBorder = Color.chooAmber.opacity(0.55)
    private static let chipBackground = Color.white.opacity(0.07)
    private static let chipBorder = Color.white.opacity(0.12)

    // MARK: - Derived state

    /// True while a meal is picked up and waiting to be dropped on a night.
    private var isArmed: Bool { pickedRecipeId != nil }

    private var plannedCount: Int { viewModel.plannedCount }

    /// Recipes not already on the board this week — the pool you plan from.
    private var poolRecipes: [Recipe] {
        let assigned = Set(viewModel.assignments.values.map(\.recipeId))
        return viewModel.firestoreService.recipes
            .filter { recipe in
                guard let id = recipe.id else { return false }
                return !assigned.contains(id)
            }
            .sorted { isNew($0) && !isNew($1) }
    }

    /// A recipe the family didn't cook last week reads as "new" this week.
    private func isNew(_ recipe: Recipe) -> Bool {
        guard let id = recipe.id else { return false }
        return !viewModel.lastWeekRecipeIds.contains(id)
    }

    private var freeNightCount: Int { 7 - plannedCount }

    private var newThisWeekCount: Int {
        viewModel.assignments.values.filter { !viewModel.lastWeekRecipeIds.contains($0.recipeId) }.count
    }

    /// First night with nothing on it, falling back to today.
    private var firstFreeNightIndex: Int {
        for index in 0..<7 where viewModel.assignments[String(index)] == nil {
            return index
        }
        return viewModel.todayIndex ?? 0
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            weekMosaic
                .padding(.top, 2)

            if planMode {
                mealPool
                    .padding(.top, 18)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: planMode)
        .confirmationDialog("Clear this dinner?", isPresented: Binding(
            get: { dayToClear != nil },
            set: { if !$0 { dayToClear = nil } }
        ), titleVisibility: .visible) {
            Button("Clear Dinner", role: .destructive) {
                if let day = dayToClear {
                    let index = day.id
                    dayToClear = nil
                    Task { await viewModel.clearDay(index) }
                }
            }
            Button("Cancel", role: .cancel) { dayToClear = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("Dinners")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            Text("\(plannedCount)/7 planned")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))

            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { planMode.toggle() }
                pickedRecipeId = nil
            } label: {
                Text(planMode ? "Done" : "Plan")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(planMode ? Color.chooAmber.opacity(0.9) : Self.chipBackground, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            planMode ? Color.chooAmber.opacity(0.9) : .white.opacity(0.14),
                            lineWidth: 1
                        )
                    )
                    .foregroundStyle(planMode ? Color(red: 0.10, green: 0.06, blue: 0.02) : .white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Week mosaic

    /// Mon–Wed across the top, then Thu/Fri and Sat/Sun in pairs.
    private var weekMosaic: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    nightTile(index: index, compact: true)
                }
            }
            .frame(height: 104)

            HStack(spacing: 8) {
                ForEach(3..<5, id: \.self) { index in
                    nightTile(index: index, compact: false)
                }
            }
            .frame(height: 96)

            HStack(spacing: 8) {
                ForEach(5..<7, id: \.self) { index in
                    nightTile(index: index, compact: false)
                }
            }
            .frame(height: 96)
        }
    }

    @ViewBuilder
    private func nightTile(index: Int, compact: Bool) -> some View {
        let date = viewModel.weekDays[index]
        let assignment = viewModel.assignments[String(index)]
        let recipe = assignment.flatMap { viewModel.recipe(for: $0) }
        let isToday = index == viewModel.todayIndex
        let isPast = viewModel.isPast(date)
        let hasMeal = assignment != nil

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Text(viewModel.dayAbbreviation(for: date).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(isToday ? Color.chooAmber : .white.opacity(0.75))

                Text(viewModel.dayNumber(for: date))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))

                Spacer(minLength: 0)

                if let meal = assignment {
                    Text(meal.recipeIcon)
                        .font(.system(size: 15))
                }
            }

            Text(assignment?.recipeName ?? "Nothing yet")
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .lineSpacing(1)
                .foregroundStyle(hasMeal ? .white : .white.opacity(0.4))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                if let recipe, isNew(recipe) {
                    Text("NEW")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(Color.chooAmber)
                } else if let prep = recipe?.prepTimeDisplay {
                    Text(prep)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBackground(hasMeal: hasMeal))
        .overlay(tileBorder(hasMeal: hasMeal))
        .opacity(isPast && !planMode ? 0.55 : 1)
        .overlay(alignment: .topTrailing) {
            if hasMeal && planMode {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await viewModel.clearDay(index) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(7)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleNightTap(index: index) }
        .onLongPressGesture {
            if viewModel.assignments[String(index)] != nil {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dayToClear = ClearDay(id: index)
            }
        }
        .dropDestination(for: String.self) { recipeIds, _ in
            guard let recipeId = recipeIds.first else { return false }
            assign(recipeId: recipeId, toDayIndex: index)
            return true
        }
    }

    private func tileBackground(hasMeal: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(hasMeal ? Self.mealBackground : (isArmed ? Self.armedBackground : Self.emptyBackground))
    }

    @ViewBuilder
    private func tileBorder(hasMeal: Bool) -> some View {
        if hasMeal {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Self.mealBorder, lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isArmed ? Self.armedBorder : Self.emptyBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        }
    }

    /// In plan mode a tap places the picked meal. Otherwise it opens the
    /// recipe picker for that night, the same as before the redesign.
    private func handleNightTap(index: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if planMode, let recipeId = pickedRecipeId {
            assign(recipeId: recipeId, toDayIndex: index)
        } else {
            viewModel.selectedDayIndex = index
        }
    }

    private func assign(recipeId: String, toDayIndex index: Int) {
        guard let recipe = viewModel.firestoreService.recipes.first(where: { $0.id == recipeId }) else { return }
        pickedRecipeId = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { await viewModel.assignRecipe(recipe, toDayIndex: index) }
    }

    // MARK: - Meal pool (plan mode)

    private var mealPool: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("MEALS TO PLACE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 0)

                Text(pickedRecipeId == nil ? "drag onto a night" : "tap a night")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.chooAmber.opacity(0.85))
            }
            .padding(.bottom, 10)

            FlowLayout(spacing: 8) {
                ForEach(poolRecipes) { recipe in
                    mealChip(recipe)
                }
                addMealChip
            }

            FlowLayout(spacing: 6) {
                ForEach(planHints, id: \.self) { hint in
                    Text(hint)
                        .font(.caption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Self.chipBackground, in: Capsule())
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.top, 14)
        }
    }

    private var planHints: [String] {
        var hints: [String] = []
        hints.append(freeNightCount == 0 ? "Week is full" : "\(freeNightCount) night\(freeNightCount == 1 ? "" : "s") free")
        hints.append("\(newThisWeekCount) new this week")
        if poolRecipes.isEmpty {
            hints.append("Every recipe is on the board")
        }
        return hints
    }

    private func mealChip(_ recipe: Recipe) -> some View {
        let isPicked = pickedRecipeId == recipe.id

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Text(recipe.icon)
                    .font(.system(size: 15))
                Text(recipe.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 6) {
                if let prep = recipe.prepTimeDisplay {
                    Text(prep)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                if isNew(recipe) {
                    Text("NEW")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(Color.chooAmber)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isPicked ? Color.chooAmber.opacity(0.20) : Self.chipBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isPicked ? Color.chooAmber.opacity(0.75) : Self.chipBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            pickedRecipeId = isPicked ? nil : recipe.id
        }
        .draggable(recipe.id ?? "") {
            Text("\(recipe.icon) \(recipe.name)")
                .font(.system(size: 13, weight: .semibold))
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var addMealChip: some View {
        Text("+ Add meal")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.selectedDayIndex = firstFreeNightIndex
            }
    }
}

// MARK: - Flow layout

/// Wraps its subviews onto as many rows as they need — used for the meal pool
/// and the hint pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layoutRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: maxWidth == .infinity ? rows.map(\.width).max() ?? 0 : maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layoutRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthWithSpacing = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if !current.indices.isEmpty && widthWithSpacing > maxWidth {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = widthWithSpacing
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
