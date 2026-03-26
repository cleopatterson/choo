import SwiftUI

struct HouseChoreListView: View {
    @Bindable var viewModel: HouseViewModel
    var scrollProxy: ScrollViewProxy?
    @State private var choreToDelete: HouseViewModel.HouseDueItem?
    @State private var showingManageCategories = false

    var body: some View {
        let groups = viewModel.itemsByCategory
        if !groups.isEmpty {
            VStack(spacing: 0) {
                Text("JOBS")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)

                VStack(spacing: 8) {
                    ForEach(groups, id: \.name) { group in
                        categoryCard(group)
                            .id("house_\(group.name)")
                    }
                }
            }
            .confirmationDialog(
                "Delete \"\(choreToDelete?.choreType.name ?? "")\"?",
                isPresented: Binding(
                    get: { choreToDelete != nil },
                    set: { if !$0 { choreToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let item = choreToDelete,
                       let category = viewModel.categories.first(where: { $0.choreTypes.contains(where: { $0.id == item.id }) }) {
                        Task { await viewModel.deleteChoreType(from: category, typeId: item.id) }
                        choreToDelete = nil
                    }
                }
            }
            .sheet(isPresented: $showingManageCategories) {
                HouseManageSheet(viewModel: viewModel, initialMode: .manageCategories)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Category Accordion Card

    @ViewBuilder
    private func categoryCard(_ group: (name: String, emoji: String, colorHex: String, items: [HouseViewModel.HouseDueItem])) -> some View {
        let isExpanded = viewModel.expandedJobCategory == group.name
        let dueCount = group.items.filter(\.isDue).count
        let overdueCount = group.items.filter(\.isOverdue).count

        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text(group.emoji)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: group.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if overdueCount > 0 {
                    Text("\(overdueCount) overdue")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color(hex: "#ef4444"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#ef4444").opacity(0.1), in: Capsule())
                } else if dueCount > 0 {
                    Text("\(dueCount) due")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.chooRose)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.chooRose.opacity(0.1), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.22), value: isExpanded)
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.expandedJobCategory = isExpanded ? nil : group.name
                if !isExpanded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy?.scrollTo("house_\(group.name)", anchor: .top)
                        }
                    }
                }
            }
            .onLongPressGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingManageCategories = true
            }

            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().overlay(.white.opacity(0.06))

                    List {
                        ForEach(group.items) { item in
                            choreRow(item)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.selectedChoreForAction = item
                                }
                                .onLongPressGesture {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    viewModel.selectedChoreForEdit = item
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        choreToDelete = item
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(group.items.count) * 52)
                }
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
    }

    // MARK: - Chore Row

    private func choreRow(_ item: HouseViewModel.HouseDueItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor(for: item))
                .frame(width: 8, height: 8)

            Text(item.choreType.name)
                .font(.subheadline)
                .foregroundStyle(item.isDue ? .primary : .secondary)

            Spacer()

            if item.isOverdue {
                Text("Overdue")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#ef4444").opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(Color(hex: "#ef4444"))
            } else if item.isDue {
                Text("Due")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.chooRose.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.chooRose)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func statusColor(for item: HouseViewModel.HouseDueItem) -> Color {
        if item.isOverdue { return Color(hex: "#ef4444") }
        if item.isDue { return Color.chooRose }
        return Color(hex: "#00b894")
    }
}
