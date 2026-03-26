import SwiftUI

struct HouseCategoriesView: View {
    @Bindable var viewModel: HouseViewModel
    var scrollProxy: ScrollViewProxy?

    @State private var addingTypeTo: ChoreCategory?
    @State private var editingType: (category: ChoreCategory, choreType: ChoreType)?

    var body: some View {
        VStack(spacing: 0) {
            Text("MANAGE CATEGORIES")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            VStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    categoryCard(category)
                        .id("housecat_\(category.id ?? category.name)")
                }
            }
        }
        .sheet(item: Binding(
            get: { addingTypeTo.map { HouseSheetCategory(category: $0) } },
            set: { addingTypeTo = $0?.category }
        )) { item in
            HouseChoreTypeFormSheet(category: item.category) { name, description, duration, frequency in
                await viewModel.addChoreType(
                    to: item.category,
                    name: name,
                    description: description,
                    durationMinutes: duration,
                    frequency: frequency
                )
                addingTypeTo = nil
            }
        }
        .sheet(item: Binding(
            get: { editingType.map { HouseSheetChoreType(category: $0.category, choreType: $0.choreType) } },
            set: { editingType = $0.map { (category: $0.category, choreType: $0.choreType) } }
        )) { item in
            HouseChoreTypeFormSheet(category: item.category, existingType: item.choreType) { name, description, duration, frequency in
                await viewModel.updateChoreType(
                    in: item.category,
                    typeId: item.choreType.id,
                    name: name,
                    description: description,
                    durationMinutes: duration,
                    frequency: frequency
                )
                editingType = nil
            }
        }
    }

    // MARK: - Category Card

    @ViewBuilder
    private func categoryCard(_ category: ChoreCategory) -> some View {
        let isExpanded = viewModel.expandedCategoryId == category.id

        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.expandedCategoryId = isExpanded ? nil : category.id
                }
                if !isExpanded {
                    let catId = category.id ?? category.name
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy?.scrollTo("housecat_\(catId)", anchor: .top)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(category.emoji)
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: category.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(category.choreTypes.count) type\(category.choreTypes.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    let dueCount = viewModel.allItems
                        .filter { $0.categoryName == category.name && $0.isDue }
                        .count
                    if dueCount > 0 {
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
                }
            }
            .padding(12)

            if isExpanded {
                VStack(spacing: 0) {
                    Divider().overlay(.white.opacity(0.06))

                    List {
                        ForEach(category.choreTypes) { choreType in
                            choreTypeRow(choreType, category: category)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingType = (category: category, choreType: choreType)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteChoreType(from: category, typeId: choreType.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(category.choreTypes.count) * 56)

                    Button {
                        addingTypeTo = category
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.caption2)
                            Text("Add type")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
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

    // MARK: - Chore Type Row

    private func choreTypeRow(_ choreType: ChoreType, category: ChoreCategory) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(choreType.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(choreType.effectiveFrequency.displayName)
                        .font(.caption2)
                        .foregroundStyle(Color.chooRose)

                    if let dur = choreType.durationDisplay {
                        Text(dur)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !choreType.description.isEmpty {
                        Text(choreType.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Identifiable wrappers

private struct HouseSheetCategory: Identifiable {
    let category: ChoreCategory
    var id: String { category.id ?? category.name }
}

private struct HouseSheetChoreType: Identifiable {
    let category: ChoreCategory
    let choreType: ChoreType
    var id: String { choreType.id }
}
