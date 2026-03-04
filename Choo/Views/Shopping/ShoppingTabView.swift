import SwiftUI

struct ShoppingTabView: View {
    @Bindable var viewModel: ShoppingViewModel
    @Bindable var dinnerPlannerViewModel: DinnerPlannerViewModel
    @Binding var showingProfile: Bool

    @State private var editingItem: ShoppingItem?
    @State private var editText = ""
    @State private var inlineAddIndex: Int? // index in sortedItems where inline field appears
    @State private var inlineAddText = ""
    @State private var inlineAddBeforeItemId: String? // ID of item that should follow the new item
    @FocusState private var inlineAddFocused: Bool
    @FocusState private var editFieldFocused: Bool

    // Track row frames for spread gesture hit detection
    @State private var rowFrames: [Int: CGRect] = [:]
    @State private var isSpreadActive = false
    @State private var reorderMode = false
    @State private var collapsedGroups: Set<String> = []
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                // Dinner planner strip
                DinnerStripView(viewModel: dinnerPlannerViewModel)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))

                if !viewModel.sortedItems.isEmpty {
                    Text("SHOPPING LIST")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1.5)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

                    Section {
                        let items = viewModel.sortedItems

                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            // Inline add field BEFORE this row (when inserting at this index)
                            if inlineAddIndex == index {
                                inlineAddRow
                            }

                            Group {
                                if item.heading {
                                    headingRow(item, collapsed: collapsedGroups.contains(item.id ?? ""))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if inlineAddIndex != nil {
                                                inlineAddFocused = false
                                                return
                                            }
                                            withAnimation(.easeInOut(duration: 0.35)) {
                                                if let id = item.id {
                                                    if collapsedGroups.contains(id) {
                                                        collapsedGroups.remove(id)
                                                    } else {
                                                        collapsedGroups.insert(id)
                                                    }
                                                }
                                            }
                                        }
                                } else if !isItemCollapsed(index: index, items: items) {
                                    itemRow(item)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if inlineAddIndex != nil {
                                                inlineAddFocused = false
                                                return
                                            }
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            Task { await viewModel.toggleItem(item) }
                                        }
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteItem(item) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editText = item.name
                                    editingItem = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                            .onLongPressGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation {
                                    collapsedGroups.removeAll()
                                    reorderMode = true
                                }
                            }
                            .listRowBackground(rowBackground(for: item))
                            .background {
                                if isSpreadActive {
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: RowFramePreference.self,
                                            value: [index: geo.frame(in: .global)]
                                        )
                                    }
                                }
                            }
                        }
                        .onMove { source, destination in
                            viewModel.moveItems(from: source, to: destination)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation { reorderMode = false }
                            }
                        }

                        // Inline add at end of list
                        if inlineAddIndex == items.count {
                            inlineAddRow
                        }
                    }
                }

                if viewModel.firestoreService.shoppingItems.isEmpty && inlineAddIndex == nil {
                    VStack(spacing: 12) {
                        Text("🛒")
                            .font(.system(size: 36))
                        Text("No items yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Tap + to add items")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .environment(\.editMode, reorderMode ? .constant(.active) : .constant(.inactive))
            .refreshable { insertAtUnsortedSection() }
            .onPreferenceChange(RowFramePreference.self) { rowFrames = $0 }
            .simultaneousGesture(spreadGesture)
            .chooBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .opacity(0.6)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Shopping")
                        .font(.system(.headline, design: .serif))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if reorderMode {
                        Button("Done") {
                            withAnimation { reorderMode = false }
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button {
                            insertAtUnsortedSection()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .onAppear { scrollProxy = proxy }
            .task { await viewModel.ensureDefaultList() }
            .task { await dinnerPlannerViewModel.load() }
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
            .overlay {
                if let error = viewModel.errorMessage {
                    ErrorBannerView(message: error) {
                        viewModel.errorMessage = nil
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            } // ScrollViewReader
        }
    }

    // MARK: - Spread Gesture

    private var spreadGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if !isSpreadActive {
                    isSpreadActive = true
                }
                guard inlineAddIndex == nil, value.magnification > 1.4 else { return }
                let centerY = value.startLocation.y
                insertAtPosition(y: centerY)
            }
            .onEnded { _ in
                // Keep active briefly so frames are captured for the insert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSpreadActive = false
                }
            }
    }

    private func insertAtPosition(y: CGFloat) {
        let items = viewModel.sortedItems
        guard !items.isEmpty else {
            openInlineAdd(at: 0)
            return
        }

        // Find which gap the gesture center falls in
        let sorted = rowFrames.sorted { $0.key < $1.key }
        for (_, entry) in sorted.enumerated() {
            if y < entry.value.midY {
                openInlineAdd(at: entry.key)
                return
            }
        }
        // Below all rows — add at end
        openInlineAdd(at: items.count)
    }

    // MARK: - Plus Button: Insert at Unsorted Section

    private func insertAtUnsortedSection() {
        openInlineAdd(at: 0)
    }

    private func openInlineAdd(at index: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let items = viewModel.sortedItems
        // Capture the ID of the item at this index — this is the item that should come AFTER the new item
        if index < items.count {
            inlineAddBeforeItemId = items[index].id
        } else {
            inlineAddBeforeItemId = nil // append at end
        }
        inlineAddText = ""
        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            inlineAddIndex = index
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            inlineAddFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation {
                scrollProxy?.scrollTo("inline-add", anchor: .center)
            }
        }
    }

    // MARK: - Inline Add Row

    private var inlineAddRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .foregroundStyle(Color.chooPurple.opacity(0.5))
                .font(.title3)
                .frame(width: 24)

            TextField("Add item... (ALL CAPS = heading)", text: $inlineAddText)
                .focused($inlineAddFocused)
                .onSubmit { submitInlineItem() }
                .onChange(of: inlineAddFocused) {
                    if !inlineAddFocused {
                        withAnimation(.spring(duration: 0.25)) {
                            inlineAddIndex = nil
                        }
                    }
                }

            if !inlineAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: submitInlineItem) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(Color.chooPurple)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .listRowBackground(
            Rectangle().fill(Color.chooPurple.opacity(0.06))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.chooPurple.opacity(0.2)).frame(height: 1)
                }
        )
        .listRowSeparator(.hidden)
        .id("inline-add")
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func submitInlineItem() {
        let name = inlineAddText
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        inlineAddText = ""

        let beforeId = inlineAddBeforeItemId
        let itemNames = name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        Task {
            await viewModel.addItemsBefore(names: itemNames, beforeItemId: beforeId)
        }
        // Close the inline field after submission
        withAnimation(.spring(duration: 0.25)) {
            inlineAddIndex = nil
        }
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

    // MARK: - Collapse Helper

    private func isItemCollapsed(index: Int, items: [ShoppingItem]) -> Bool {
        for i in stride(from: index - 1, through: 0, by: -1) {
            if items[i].heading {
                return collapsedGroups.contains(items[i].id ?? "")
            }
        }
        return false // unsorted section is never collapsed
    }

    // MARK: - Heading Row

    private func headingRow(_ item: ShoppingItem, collapsed: Bool) -> some View {
        let remaining = uncheckedCount(after: item)
        let checkedCount = checkedCount(after: item)
        return HStack(spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
                .rotationEffect(.degrees(collapsed ? 0 : 90))
                .frame(width: 24)

            Text(item.name)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            if remaining > 0 {
                Text("\(remaining)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.12), in: Capsule())
            }

            Spacer()

            if checkedCount > 0 {
                Button {
                    guard let id = item.id else { return }
                    Task { await viewModel.sortSectionByChecked(headingId: id) }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.chooPurple.opacity(0.2))
    }

    private func uncheckedCount(after heading: ShoppingItem) -> Int {
        let items = viewModel.sortedItems
        guard let headingIndex = items.firstIndex(where: { $0.id == heading.id }) else { return 0 }
        var count = 0
        for i in (headingIndex + 1)..<items.count {
            if items[i].heading { break }
            if !items[i].isChecked { count += 1 }
        }
        return count
    }

    private func checkedCount(after heading: ShoppingItem) -> Int {
        let items = viewModel.sortedItems
        guard let headingIndex = items.firstIndex(where: { $0.id == heading.id }) else { return 0 }
        var count = 0
        for i in (headingIndex + 1)..<items.count {
            if items[i].heading { break }
            if items[i].isChecked { count += 1 }
        }
        return count
    }

    // MARK: - Unsorted Label

    private var unsortedLabel: some View {
        Color.clear
            .frame(height: 1)
            .listRowBackground(Color.clear)
    }

    // MARK: - Item Row

    private func itemRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isChecked ? .green : .white.opacity(0.25))
                .font(.title3)
                .frame(width: 24)

            Text(item.name)
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? .secondary : .primary)

            Spacer()
        }
        .overlay(alignment: .trailing) {
            Text(shoppingEmoji(for: item.name))
                .font(.system(size: 24))
                .grayscale(item.isChecked ? 1.0 : 0)
                .opacity(item.isChecked ? 0.25 : 0.75)
                .allowsHitTesting(false)
        }
        .opacity(item.isChecked ? 0.5 : 1)
    }

    // MARK: - Item Emoji Matching

    private func shoppingEmoji(for name: String) -> String {
        let lower = name.lowercased()

        // Fruit & veg
        if lower.containsAny("apple", "fruit") { return "🍎" }
        if lower.containsAny("carrot", "broccoli", "spinach", "celery", "cucumber", "zucchini") { return "🥕" }
        if lower.containsAny("lettuce", "salad", "vegetable", "veg") { return "🥬" }
        if lower.containsAny("banana", "mango", "pear", "pineapple", "avocado") { return "🍌" }
        if lower.containsAny("orange", "lemon", "lime", "grape", "berry", "strawberry", "melon", "watermelon") { return "🍊" }
        if lower.containsAny("tomato") { return "🍅" }
        if lower.containsAny("potato", "onion", "garlic", "mushroom", "corn", "pea", "bean", "capsicum", "pepper", "pumpkin") { return "🥔" }

        // Meat & protein
        if lower.containsAny("chicken", "turkey") { return "🍗" }
        if lower.containsAny("meat", "beef", "steak", "lamb", "pork", "mince", "sausage", "bacon", "ham") { return "🥩" }
        if lower.containsAny("fish", "salmon", "tuna") { return "🐟" }
        if lower.containsAny("prawn", "shrimp", "seafood") { return "🦐" }
        if lower.containsAny("egg") { return "🥚" }

        // Dairy
        if lower.containsAny("milk", "cream") { return "🥛" }
        if lower.containsAny("yoghurt", "yogurt") { return "🥛" }
        if lower.containsAny("cheese") { return "🧀" }
        if lower.containsAny("butter") { return "🧈" }

        // Bakery & grains
        if lower.containsAny("bread", "loaf", "roll", "baguette", "sourdough", "toast") { return "🍞" }
        if lower.containsAny("pasta", "noodle") { return "🍝" }
        if lower.containsAny("rice", "cereal", "oat", "flour") { return "🌾" }

        // Drinks
        if lower.containsAny("water") { return "💧" }
        if lower.containsAny("juice", "drink", "soda", "coke", "lemonade", "cordial") { return "🧃" }
        if lower.containsAny("coffee") { return "☕" }
        if lower.containsAny("tea") { return "🍵" }
        if lower.containsAny("wine") { return "🍷" }
        if lower.containsAny("beer") { return "🍺" }
        if lower.containsAny("alcohol", "spirit", "vodka", "gin", "rum", "whisky") { return "🥃" }

        // Snacks & sweets
        if lower.containsAny("chip", "crisp", "snack", "cracker") { return "🍿" }
        if lower.containsAny("nut", "almond", "cashew", "peanut") { return "🥜" }
        if lower.containsAny("chocolate", "candy", "sweet", "lolly") { return "🍫" }
        if lower.containsAny("ice cream") { return "🍦" }
        if lower.containsAny("biscuit", "cookie") { return "🍪" }
        if lower.containsAny("cake") { return "🎂" }

        // Pantry
        if lower.containsAny("sauce", "ketchup", "mustard", "mayo", "dressing") { return "🫙" }
        if lower.containsAny("oil", "vinegar") { return "🫒" }
        if lower.containsAny("sugar", "salt", "spice", "herb") { return "🧂" }
        if lower.containsAny("tin", "can", "soup") { return "🥫" }

        // Household
        if lower.containsAny("toilet", "tissue", "paper towel", "kitchen roll") { return "🧻" }
        if lower.containsAny("soap", "shampoo", "conditioner", "wash", "detergent") { return "🧴" }
        if lower.containsAny("cleaning", "cleaner", "spray") { return "✨" }
        if lower.containsAny("bin bag", "garbage", "trash bag", "rubbish") { return "🗑️" }
        if lower.containsAny("sponge", "cloth", "wipe") { return "🧽" }
        if lower.containsAny("toothpaste", "toothbrush", "dental", "floss") { return "🪥" }
        if lower.containsAny("nappy", "nappies", "diaper") { return "👶" }

        // Pet
        if lower.containsAny("dog food", "cat food", "pet food", "kibble", "litter") { return "🐾" }

        // Medicine
        if lower.containsAny("medicine", "vitamin", "tablet", "pill", "panadol", "nurofen") { return "💊" }

        // Frozen
        if lower.containsAny("frozen", "ice") { return "❄️" }

        // Generic fallback
        if lower.containsAny("bag", "box") { return "📦" }

        return "🛒"
    }

    @ViewBuilder
    private func rowBackground(for item: ShoppingItem) -> some View {
        if item.heading {
            Color.clear
        } else if item.isChecked {
            Rectangle().fill(.ultraThinMaterial).opacity(0.4)
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Row Frame Preference Key

struct RowFramePreference: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.chooPurple.opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 80)
                .offset(x: phase)
                .mask(content)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
