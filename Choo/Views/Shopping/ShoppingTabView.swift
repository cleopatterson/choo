import SwiftUI

struct ShoppingTabView: View {
    @Bindable var viewModel: ShoppingViewModel
    @Bindable var dinnerPlannerViewModel: DinnerPlannerViewModel
    @Bindable var suppliesViewModel: SuppliesViewModel
    @Binding var showingProfile: Bool

    @State private var editingItem: ShoppingItem?
    @State private var editText = ""
    @State private var quickAddText = ""
    @FocusState private var quickAddFocused: Bool
    @FocusState private var editFieldFocused: Bool

    @State private var reorderMode = false
    @State private var runOpen = true
    @State private var showingDoneSheet = false
    @State private var showingAddSheet = false
    @State private var ingredientReviewRecipe: Recipe?
    @State private var itemToDelete: ShoppingItem?

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    // Dinner planner strip
                    DinnerStripView(
                        viewModel: dinnerPlannerViewModel,
                        onRecipeAssigned: { recipe in
                            ingredientReviewRecipe = recipe
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))

                    // ── This Week's Run ──
                    runCard(scrollProxy: scrollProxy)
                        .id("run")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 0, trailing: 16))

                    // ── Supplies ──
                    SuppliesSectionView(viewModel: suppliesViewModel, scrollProxy: scrollProxy)
                        .id("supplies")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .environment(\.editMode, .constant(.active))
            .chooBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingProfile = true } label: {
                        Image(systemName: "person.circle").opacity(0.6)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Shopping")
                        .font(.system(.headline, design: .serif))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if reorderMode {
                        Button("Done") { withAnimation { reorderMode = false } }
                            .fontWeight(.semibold)
                    } else {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .task { await viewModel.ensureDefaultList() }
            .task { await dinnerPlannerViewModel.load() }
            .task { await suppliesViewModel.load() }
            .sheet(item: $editingItem) { item in
                editSheet(for: item)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: Binding(
                get: { dinnerPlannerViewModel.selectedDayIndex != nil },
                set: { if !$0 { dinnerPlannerViewModel.selectedDayIndex = nil } }
            )) {
                RecipePickerView(viewModel: dinnerPlannerViewModel)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $ingredientReviewRecipe) { recipe in
                IngredientReviewSheet(
                    recipe: recipe,
                    onAdd: { ingredients in
                        Task { await addIngredientsToRun(ingredients, from: recipe) }
                    },
                    onDismiss: { ingredientReviewRecipe = nil }
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingDoneSheet) {
                RunDoneSheet(
                    checkedCount: viewModel.checkedCount,
                    uncheckedCount: viewModel.uncheckedCount,
                    onConfirm: {
                        Task { await viewModel.completeDoneFlow() }
                        showingDoneSheet = false
                    },
                    onCancel: { showingDoneSheet = false }
                )
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingAddSheet) {
                SupplyAddSheet(viewModel: suppliesViewModel)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.ultraThinMaterial)
            }
            .overlay {
                if let error = viewModel.errorMessage ?? suppliesViewModel.errorMessage {
                    ErrorBannerView(message: error) {
                        viewModel.errorMessage = nil
                        suppliesViewModel.errorMessage = nil
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }

    // MARK: - Run Card (unified header + items)

    private func runCard(scrollProxy: ScrollViewProxy) -> some View {
        let items = viewModel.runItems

        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text("🛍️")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color.chooAmber.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text("This Week's Run")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    let count = viewModel.uncheckedCount
                    Text(count > 0 ? "\(count) item\(count == 1 ? "" : "s")" : "No items yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if runOpen && viewModel.checkedCount > 0 {
                    Button {
                        showingDoneSheet = true
                    } label: {
                        Text("Done ✓")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.chooAmber)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(runOpen ? 90 : 0))
                    .animation(.easeInOut(duration: 0.25), value: runOpen)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
            .onTapGesture {
                runOpen.toggle()
                if runOpen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy.scrollTo("run", anchor: .top)
                        }
                    }
                }
            }

            // Expanded items
            if runOpen {
                Divider().overlay(.white.opacity(0.06))

                if items.isEmpty && !quickAddFocused {
                    // Empty state
                    VStack(spacing: 8) {
                        Text("🛒")
                            .font(.system(size: 28))
                        Text("Run is empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Add items or assign dinners")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Item list
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            runItemRow(item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    Task { await viewModel.toggleItem(item) }
                                }
                                .contextMenu {
                                    Button {
                                        editText = item.name
                                        editingItem = item
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                // Quick add
                Divider().overlay(.white.opacity(0.06))

                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.chooAmber.opacity(0.5))
                        .font(.callout)
                        .frame(width: 20)

                    TextField("Quick add item...", text: $quickAddText)
                        .font(.subheadline)
                        .focused($quickAddFocused)
                        .onSubmit { submitQuickAdd() }

                    if !quickAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: submitQuickAdd) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(Color.chooAmber)
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .confirmationDialog("Delete this item?", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task { await viewModel.deleteItem(item) }
                    itemToDelete = nil
                }
            }
        }
    }

    private func submitQuickAdd() {
        let name = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        quickAddText = ""

        let itemNames = name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        Task {
            for itemName in itemNames {
                await viewModel.addItem(name: itemName)
            }
        }
    }

    // MARK: - Run Item Row (inside card)

    private func runItemRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: 10) {
            // Tick
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isChecked ? Color.chooAmber : .white.opacity(0.25))
                .font(.body)
                .frame(width: 20)

            // Emoji
            Text(shoppingEmoji(for: item.name))
                .font(.subheadline)
                .frame(width: 20)

            // Name
            Text(item.name)
                .font(.subheadline)
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? .secondary : .primary)

            Spacer()

            // Source tag
            if let tag = item.cadenceTag, !tag.isEmpty {
                Text(tag)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.chooAmber.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.chooAmber)
            } else if let recipeId = item.sourceRecipeId, !recipeId.isEmpty {
                let recipeName = dinnerPlannerViewModel.firestoreService.recipes
                    .first(where: { $0.id == recipeId })?.name
                if let name = recipeName {
                    Text(name)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.chooAmber.opacity(0.1))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.chooAmber)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(item.isChecked ? 0.5 : 1)
    }

    // MARK: - Edit Sheet

    private func editSheet(for item: ShoppingItem) -> some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $editText)
                    .focused($editFieldFocused)
                    .task {
                        try? await Task.sleep(for: .milliseconds(600))
                        editFieldFocused = true
                    }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(item.heading ? "Edit Heading" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingItem = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.renameItem(item, to: editText) }
                        editingItem = nil
                    }
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - Ingredient → Run

    private func addIngredientsToRun(_ ingredients: [Ingredient], from recipe: Recipe) async {
        guard let listId = viewModel.firestoreService.shoppingLists.first?.id,
              let recipeId = recipe.id else { return }

        let existingNames = Set(viewModel.firestoreService.shoppingItems.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        })

        let nextOrder = (viewModel.firestoreService.shoppingItems.compactMap { $0.sortOrder }.max() ?? -1) + 1

        for (offset, ingredient) in ingredients.enumerated() {
            let key = ingredient.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !existingNames.contains(key) else { continue }

            let item = ShoppingItem(
                listId: listId,
                name: ingredient.name,
                isChecked: false,
                addedBy: viewModel.displayName,
                createdAt: Date(),
                sortOrder: nextOrder + offset,
                sourceRecipeId: recipeId,
                source: .meal
            )
            do {
                try await viewModel.firestoreService.addShoppingItemFull(
                    familyId: viewModel.familyId,
                    listId: listId,
                    item: item
                )
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Item Emoji Matching

    private func shoppingEmoji(for name: String) -> String {
        let lower = name.lowercased()

        if lower.containsAny("apple", "fruit") { return "🍎" }
        if lower.containsAny("carrot", "broccoli", "spinach", "celery", "cucumber", "zucchini") { return "🥕" }
        if lower.containsAny("lettuce", "salad", "vegetable", "veg") { return "🥬" }
        if lower.containsAny("banana", "mango", "pear", "pineapple", "avocado") { return "🍌" }
        if lower.containsAny("orange", "lemon", "lime", "grape", "berry", "strawberry", "melon", "watermelon") { return "🍊" }
        if lower.containsAny("tomato") { return "🍅" }
        if lower.containsAny("potato", "onion", "garlic", "mushroom", "corn", "pea", "bean", "capsicum", "pepper", "pumpkin") { return "🥔" }
        if lower.containsAny("chicken", "turkey") { return "🍗" }
        if lower.containsAny("meat", "beef", "steak", "lamb", "pork", "mince", "sausage", "bacon", "ham") { return "🥩" }
        if lower.containsAny("fish", "salmon", "tuna") { return "🐟" }
        if lower.containsAny("prawn", "shrimp", "seafood") { return "🦐" }
        if lower.containsAny("egg") { return "🥚" }
        if lower.containsAny("milk", "cream") { return "🥛" }
        if lower.containsAny("yoghurt", "yogurt") { return "🥛" }
        if lower.containsAny("cheese") { return "🧀" }
        if lower.containsAny("butter") { return "🧈" }
        if lower.containsAny("bread", "loaf", "roll", "baguette", "sourdough", "toast") { return "🍞" }
        if lower.containsAny("pasta", "noodle") { return "🍝" }
        if lower.containsAny("rice", "cereal", "oat", "flour") { return "🌾" }
        if lower.containsAny("water") { return "💧" }
        if lower.containsAny("juice", "drink", "soda", "coke", "lemonade", "cordial") { return "🧃" }
        if lower.containsAny("coffee") { return "☕" }
        if lower.containsAny("tea") { return "🍵" }
        if lower.containsAny("wine") { return "🍷" }
        if lower.containsAny("beer") { return "🍺" }
        if lower.containsAny("alcohol", "spirit", "vodka", "gin", "rum", "whisky") { return "🥃" }
        if lower.containsAny("chip", "crisp", "snack", "cracker") { return "🍿" }
        if lower.containsAny("nut", "almond", "cashew", "peanut") { return "🥜" }
        if lower.containsAny("chocolate", "candy", "sweet", "lolly") { return "🍫" }
        if lower.containsAny("ice cream") { return "🍦" }
        if lower.containsAny("biscuit", "cookie") { return "🍪" }
        if lower.containsAny("cake") { return "🎂" }
        if lower.containsAny("sauce", "ketchup", "mustard", "mayo", "dressing") { return "🫙" }
        if lower.containsAny("oil", "vinegar") { return "🫒" }
        if lower.containsAny("sugar", "salt", "spice", "herb") { return "🧂" }
        if lower.containsAny("tin", "can", "soup") { return "🥫" }
        if lower.containsAny("toilet", "tissue", "paper towel", "kitchen roll") { return "🧻" }
        if lower.containsAny("soap", "shampoo", "conditioner", "wash", "detergent") { return "🧴" }
        if lower.containsAny("cleaning", "cleaner", "spray") { return "✨" }
        if lower.containsAny("bin bag", "garbage", "trash bag", "rubbish") { return "🗑️" }
        if lower.containsAny("sponge", "cloth", "wipe") { return "🧽" }
        if lower.containsAny("toothpaste", "toothbrush", "dental", "floss") { return "🪥" }
        if lower.containsAny("nappy", "nappies", "diaper") { return "👶" }
        if lower.containsAny("dog food", "cat food", "pet food", "kibble", "litter") { return "🐾" }
        if lower.containsAny("medicine", "vitamin", "tablet", "pill", "panadol", "nurofen") { return "💊" }
        if lower.containsAny("frozen", "ice") { return "❄️" }
        if lower.containsAny("bag", "box") { return "📦" }

        return "🛒"
    }
}

