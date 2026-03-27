import SwiftUI

struct DinnerStripView: View {
    @Bindable var viewModel: DinnerPlannerViewModel
    var onRecipeAssigned: ((Recipe) -> Void)?
    @State private var dayToClear: ClearDay?

    private struct ClearDay: Identifiable {
        let id: Int
    }

    private var todayIndex: Int? { viewModel.todayIndex }

    /// All days for the strip (today included but styled differently).
    private var allDays: [(index: Int, date: Date)] {
        Array(viewModel.weekDays.enumerated())
            .map { (index: $0.offset, date: $0.element) }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Layer 1: AI Briefing Card
            BriefingCardView(
                badge: "Dinners this week",
                dateRange: viewModel.weekDateRange,
                headline: viewModel.briefingHeadline,
                summary: viewModel.briefingSummary,
                accent: .shopping,
                isLoading: viewModel.isLoadingBriefing
            )

            // Layer 2: Hero Card — tonight's dinner
            tonightHeroCard

            // Layer 3+: Day card strip
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allDays, id: \.index) { day in
                            dayCard(index: day.index, date: day.date)
                                .id(day.index)
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.selectedDayIndex = day.index
                                }
                                .onLongPressGesture {
                                    let key = String(day.index)
                                    if viewModel.assignments[key] != nil {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        dayToClear = ClearDay(id: day.index)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onAppear {
                    if let firstUpcoming = allDays.first(where: { !viewModel.isPast($0.date) }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(firstUpcoming.index, anchor: .leading)
                            }
                        }
                    }
                }
            }

            // Stats bar
            if viewModel.plannedCount > 0 {
                Text("\(viewModel.plannedCount) of 7 nights planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: viewModel.lastAssignedRecipe?.id) {
            if let recipe = viewModel.lastAssignedRecipe {
                viewModel.lastAssignedRecipe = nil
                onRecipeAssigned?(recipe)
            }
        }
        .confirmationDialog("Clear this dinner?", isPresented: Binding(
            get: { dayToClear != nil },
            set: { if !$0 { dayToClear = nil } }
        ), titleVisibility: .visible) {
            Button("Clear Dinner", role: .destructive) {
                if let day = dayToClear {
                    let idx = day.id
                    dayToClear = nil
                    Task { await viewModel.clearDay(idx) }
                }
            }
            Button("Cancel", role: .cancel) {
                dayToClear = nil
            }
        }
    }

    // MARK: - Tonight Hero Card

    @ViewBuilder
    private var tonightHeroCard: some View {
        if let todayIdx = todayIndex {
            let assignment = viewModel.todayAssignment
            let recipe = viewModel.todayRecipe

            Group {
                if let meal = assignment {
                    let heroSubtitle: String = recipe?.prepTimeDisplay ?? ""

                    HeroCardView(
                        label: viewModel.todayDayLabel,
                        title: meal.recipeName,
                        subtitle: heroSubtitle,
                        emoji: meal.recipeIcon,
                        accent: .shopping
                    ) {
                        heroPills(for: recipe)
                    }
                } else {
                    HeroCardView(
                        label: viewModel.todayDayLabel,
                        title: "",
                        subtitle: "",
                        emoji: "",
                        accent: .shopping,
                        isEmpty: true,
                        emptyMessage: "What's for dinner?"
                    ) { EmptyView() }
                }
            }
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.selectedDayIndex = todayIdx
            }
            .onLongPressGesture {
                let key = String(todayIdx)
                if viewModel.assignments[key] != nil {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dayToClear = ClearDay(id: todayIdx)
                }
            }
        }
    }

    // MARK: - Hero Pills

    @ViewBuilder
    private func heroPills(for recipe: Recipe?) -> some View {
        if let recipe {
            // Cuisine pill (colored by region)
            if let cuisine = recipe.cuisineType {
                HeroCardView<EmptyView>.coloredPill(
                    text: cuisine.displayName,
                    color: cuisineColor(cuisine)
                )
            }

            // Richness pill (green→red ramp)
            if let richness = recipe.calorieDensityEnum {
                HeroCardView<EmptyView>.coloredPill(
                    text: richness.displayName,
                    color: richnessColor(richness)
                )
            }
        } else {
            HeroCardView<EmptyView>.pillBadge(text: "🍽️ Dinner")
        }
    }

    // MARK: - Compact Day Card

    @ViewBuilder
    private func dayCard(index: Int, date: Date) -> some View {
        let key = String(index)
        let assignment = viewModel.assignments[key]
        let recipe = assignment.flatMap { viewModel.recipe(for: $0) }
        let isPast = viewModel.isPast(date)
        let isFeatured = index == todayIndex

        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.dayAbbreviation(for: date))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isFeatured ? Color.chooAmber.opacity(0.6) : (isPast ? .white.opacity(0.3) : .secondary))

                Spacer(minLength: 0)

                if isFeatured {
                    Text("TONIGHT")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(Color.chooAmber.opacity(0.8))
                        .tracking(0.5)
                } else {
                    Text(viewModel.dayNumber(for: date))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isPast ? .white.opacity(0.3) : .secondary)
                }
            }

            if let meal = assignment {
                Spacer(minLength: 4)
                Text(meal.recipeIcon)
                    .font(.system(size: 28))
                    .frame(height: 34)

                Text(meal.recipeName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPast ? .white.opacity(0.35) : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity)

                // Prep time with clock
                if let recipe, let prep = recipe.prepTimeDisplay {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(prep)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 4)
            } else {
                Spacer(minLength: 4)
                Image(systemName: "plus")
                    .font(.body)
                    .foregroundStyle(isPast ? .white.opacity(0.08) : .white.opacity(0.15))
                    .frame(height: 34)

                Text("Add")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(isPast ? 0.15 : 0.3))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 4)
            }
        }
        .frame(width: 120)
        .frame(minHeight: 120)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .opacity(isPast ? 0.6 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Pill Color Helpers

    private func cuisineColor(_ cuisine: CuisineType) -> Color {
        switch cuisine {
        case .italian: Color(red: 1.0, green: 0.39, blue: 0.28)   // tomato red
        case .asian: Color(red: 1.0, green: 0.65, blue: 0.0)      // orange
        case .mexican: Color(red: 1.0, green: 0.48, blue: 0.33)   // flame
        case .greek: Color(red: 0.28, green: 0.82, blue: 0.80)    // teal
        case .bbq: Color(red: 0.82, green: 0.41, blue: 0.12)      // brown
        case .comfort: Color(red: 0.58, green: 0.44, blue: 0.86)  // purple
        case .other: .white.opacity(0.6)
        }
    }

private func richnessColor(_ richness: CalorieDensity) -> Color {
        switch richness {
        case .light: Color(red: 0.0, green: 0.72, blue: 0.58)     // green
        case .moderate: Color(red: 0.99, green: 0.80, blue: 0.43) // yellow
        case .rich: Color(red: 1.0, green: 0.42, blue: 0.42)      // red
        }
    }
}
