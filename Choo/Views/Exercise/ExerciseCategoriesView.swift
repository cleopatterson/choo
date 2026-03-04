import SwiftUI

struct ExerciseCategoriesView: View {
    @Bindable var viewModel: ExerciseViewModel

    @State private var addingTypeTo: ExerciseCategory?
    @State private var editingType: (category: ExerciseCategory, sessionType: SessionType)?

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Text("YOUR CATEGORIES")
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
    }

    // MARK: - Category Card

    @ViewBuilder
    private func categoryCard(_ category: ExerciseCategory) -> some View {
        let isExpanded = viewModel.expandedCategoryId == category.id
        let scheduledCount = viewModel.scheduledCount(for: category)

        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.expandedCategoryId = isExpanded ? nil : category.id
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
                        Text("\(category.sessionTypes.count) type\(category.sessionTypes.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if scheduledCount > 0 {
                        Text("\(scheduledCount)× this week")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color(hex: "#4ecdc4"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#4ecdc4").opacity(0.1), in: Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .padding(12)

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
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteSessionType(from: category, typeId: sessionType.id)
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

            VStack(alignment: .leading, spacing: 2) {
                Text(sessionType.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let dur = sessionType.durationDisplay {
                        Text(dur)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let cal = sessionType.estimatedCalories, cal > 0 {
                        Text("~\(cal) cal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let intensity = sessionType.intensityEnum {
                        Text("⚡ \(intensity.displayName)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(intensityColor(intensity))
                    }
                }
            }

            Spacer()

            let count = viewModel.scheduledCount(for: sessionType)
            if count > 0 {
                Text("\(count)×")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func intensityColor(_ intensity: ExerciseIntensity) -> Color {
        switch intensity {
        case .light: Color(red: 0.0, green: 0.72, blue: 0.58)
        case .moderate: Color(red: 0.99, green: 0.80, blue: 0.43)
        case .high: Color(red: 0.95, green: 0.57, blue: 0.24)
        case .peak: Color(red: 1.0, green: 0.42, blue: 0.42)
        }
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
