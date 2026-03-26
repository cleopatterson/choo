import SwiftUI

struct SuppliesSectionView: View {
    @Bindable var viewModel: SuppliesViewModel
    var scrollProxy: ScrollViewProxy?
    @State private var isOpen = false
    @State private var expandedCategories: Set<String> = []
    @State private var editingSupply: SupplyItem?
    @State private var isAddingSupply = false
    @State private var showingCategoryManage = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text("🧺")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color.chooPurple.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Supplies")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(viewModel.totalCount) item\(viewModel.totalCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.lowCount > 0 {
                    Text("\(viewModel.lowCount) low")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.1), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .animation(.easeInOut(duration: 0.25), value: isOpen)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
            .onTapGesture {
                isOpen.toggle()
                if isOpen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy?.scrollTo("supplies", anchor: .top)
                        }
                    }
                }
            }
            .onLongPressGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingCategoryManage = true
            }

            // Expanded categories inside the same card
            if isOpen {
                Divider().overlay(.white.opacity(0.06))

                VStack(spacing: 6) {
                    ForEach(viewModel.groupedByCategory, id: \.category) { group in
                        categoryBlock(group.category, items: group.items)
                            .id("supply_\(group.category.rawValue)")
                    }

                    // Add button at bottom
                    Button {
                        isAddingSupply = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.caption2)
                            Text("Add supply")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
                .padding(8)
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
        .sheet(item: $editingSupply) { supply in
            NavigationStack {
                SupplyItemFormSheet(
                    category: supply.category,
                    existingItem: supply,
                    onSave: { name, cat, cadence, aisle in
                        Task { await viewModel.updateItem(supply, name: name, category: cat, cadence: cadence, aisleOrder: aisle) }
                        editingSupply = nil
                    },
                    onDelete: {
                        Task { await viewModel.deleteItem(supply) }
                        editingSupply = nil
                    }
                )
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $isAddingSupply) {
            SupplyAddSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingCategoryManage) {
            SupplyCategoryManageSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Category Block

    @ViewBuilder
    private func categoryBlock(_ category: SupplyCategory, items: [SupplyItem]) -> some View {
        let key = category.rawValue
        let isExpanded = expandedCategories.contains(key)

        VStack(spacing: 0) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.22), value: isExpanded)

                Text(category.emoji)
                    .font(.subheadline)

                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(items.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                if isExpanded {
                    expandedCategories.remove(key)
                } else {
                    expandedCategories.insert(key)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy?.scrollTo("supply_\(key)", anchor: .top)
                        }
                    }
                }
            }

            // Items
            if isExpanded {
                ForEach(items) { item in
                    supplyItemRow(item)
                }
            }
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.06))
        )
    }

    // MARK: - Supply Item Row

    private func supplyItemRow(_ item: SupplyItem) -> some View {
        HStack(spacing: 10) {
            // Tappable area for editing
            HStack(spacing: 10) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if item.status == .low || item.status == .due {
                    statusPill(item.status)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                editingSupply = item
            }

            // Add to run toggle
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await viewModel.toggleRunState(item) }
            } label: {
                let inRun = viewModel.isInRun(item)
                Image(systemName: inRun ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(inRun ? Color.chooAmber : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Status Pill

    @ViewBuilder
    private func statusPill(_ status: SupplyStatus) -> some View {
        switch status {
        case .ok:
            EmptyView()
        case .due:
            Text("Due")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.chooAmber.opacity(0.12))
                .clipShape(Capsule())
                .foregroundStyle(Color.chooAmber)
        case .low:
            Text("Running low")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
                .foregroundStyle(.red)
        }
    }
}

extension SupplyItem: @retroactive Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SupplyItem, rhs: SupplyItem) -> Bool {
        lhs.id == rhs.id
    }
}
