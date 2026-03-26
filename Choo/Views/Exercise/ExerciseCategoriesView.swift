import SwiftUI

struct ExerciseCategoriesView: View {
    @Bindable var viewModel: ExerciseViewModel
    var scrollProxy: ScrollViewProxy?

    @State private var addingTypeTo: ExerciseCategory?
    @State private var editingType: (category: ExerciseCategory, sessionType: SessionType)?
    @State private var deletingType: (category: ExerciseCategory, sessionType: SessionType)?
    @State private var showingManageCategories = false

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Text("SESSIONS")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            // Category list
            VStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    categoryCard(category)
                        .id("exercise_\(category.id ?? category.name)")
                }
            }
        }
        .sheet(item: Binding(
            get: { addingTypeTo.map { SheetCategory(category: $0) } },
            set: { addingTypeTo = $0?.category }
        )) { item in
            SessionTypeFormSheet(category: item.category) { name, description, duration, calories, intensity in
                await viewModel.addSessionType(
                    to: item.category,
                    name: name,
                    description: description,
                    durationMinutes: duration,
                    estimatedCalories: calories,
                    intensity: intensity
                )
                addingTypeTo = nil
            }
        }
        .sheet(item: Binding(
            get: { editingType.map { SheetSessionType(category: $0.category, sessionType: $0.sessionType) } },
            set: { editingType = $0.map { (category: $0.category, sessionType: $0.sessionType) } }
        )) { item in
            SessionTypeFormSheet(category: item.category, existingType: item.sessionType) { name, description, duration, calories, intensity in
                await viewModel.updateSessionType(
                    in: item.category,
                    typeId: item.sessionType.id,
                    name: name,
                    description: description,
                    durationMinutes: duration,
                    estimatedCalories: calories,
                    intensity: intensity
                )
                editingType = nil
            }
        }
        .confirmationDialog(
            "Delete \"\(deletingType?.sessionType.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingType != nil },
                set: { if !$0 { deletingType = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let dt = deletingType {
                    Task { await viewModel.deleteSessionType(from: dt.category, typeId: dt.sessionType.id) }
                    deletingType = nil
                }
            }
        }
        .sheet(isPresented: $showingManageCategories) {
            ExerciseManageSheet(viewModel: viewModel, initialMode: .manageCategories)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Category Card

    @ViewBuilder
    private func categoryCard(_ category: ExerciseCategory) -> some View {
        let isExpanded = viewModel.expandedCategoryId == category.id

        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text(category.emoji)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: category.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.22), value: isExpanded)
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.expandedCategoryId = isExpanded ? nil : category.id
                if !isExpanded {
                    let catId = category.id ?? category.name
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy?.scrollTo("exercise_\(catId)", anchor: .top)
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
                        ForEach(category.sessionTypes) { sessionType in
                            sessionTypeRow(sessionType, category: category)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingType = (category: category, sessionType: sessionType)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deletingType = (category: category, sessionType: sessionType)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(category.sessionTypes.count) * 56)

                    // Add type button
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

    // MARK: - Session Type Row

    private func sessionTypeRow(_ sessionType: SessionType, category: ExerciseCategory) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 8, height: 8)

            Text(sessionType.name)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            if let dur = sessionType.durationDisplay {
                Text(dur)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

}

// MARK: - Identifiable wrappers for sheets

private struct SheetCategory: Identifiable {
    let category: ExerciseCategory
    var id: String { category.id ?? category.name }
}

private struct SheetSessionType: Identifiable {
    let category: ExerciseCategory
    let sessionType: SessionType
    var id: String { sessionType.id }
}
