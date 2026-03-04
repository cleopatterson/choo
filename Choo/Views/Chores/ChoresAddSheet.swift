import SwiftUI

struct ChoresAddSheet: View {
    @Bindable var viewModel: ChoresViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAssignee: ChoreAssignee?
    @State private var selectedCategory: ChoreCategory?
    @State private var step: Step = .pickCategory
    @State private var capturedDayIndex: Int = 0

    private enum Step {
        case pickCategory
        case pickChore
    }

    private var dayIndex: Int {
        capturedDayIndex
    }

    private var dayLabel: String {
        guard dayIndex < viewModel.weekDays.count else { return "" }
        let date = viewModel.weekDays[dayIndex]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch step {
                case .pickCategory:
                    categoryStep
                case .pickChore:
                    choreStep
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle(step == .pickCategory ? "Add Chore" : "Pick a Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.selectedDayIndex = nil
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            capturedDayIndex = viewModel.selectedDayIndex ?? 0
            if selectedAssignee == nil {
                selectedAssignee = viewModel.availableAssignees.first
            }
        }
    }

    // MARK: - Step 1: Pick Person + Category

    private var categoryStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Person picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("ASSIGNED TO")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.availableAssignees) { assignee in
                                assigneePill(assignee)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Category list
                VStack(alignment: .leading, spacing: 8) {
                    Text("CATEGORY")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)
                        .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(viewModel.categories) { category in
                            categoryRow(category)
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedCategory = category
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        step = .pickChore
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func assigneePill(_ assignee: ChoreAssignee) -> some View {
        let isSelected = selectedAssignee?.id == assignee.id
        let accentColor = Color(hex: assignee.colorHex)
        return Button {
            selectedAssignee = assignee
        } label: {
            HStack(spacing: 4) {
                Text(assignee.emoji)
                Text(assignee.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accentColor.opacity(0.15) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? accentColor.opacity(0.5) : .white.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .foregroundStyle(isSelected ? accentColor : .secondary)
        }
    }

    private func categoryRow(_ category: ChoreCategory) -> some View {
        HStack(spacing: 12) {
            Text(category.emoji)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color(hex: category.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                Text(category.choreTypes.map(\.name).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Step 2: Pick Chore Type

    private var choreStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .pickCategory
                        selectedCategory = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.chooCoral)
                }
                .padding(.horizontal)

                if let category = selectedCategory {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pick a \(category.name) chore")
                            .font(.headline)
                        Text("For \(dayLabel) \u{00B7} \(selectedAssignee?.emoji ?? "") \(selectedAssignee?.displayName ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(category.choreTypes) { choreType in
                            choreTypeRow(choreType, category: category)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func choreTypeRow(_ choreType: ChoreType, category: ChoreCategory) -> some View {
        Button {
            guard let assignee = selectedAssignee else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await viewModel.assignChore(
                    dayIndex: dayIndex,
                    choreType: choreType,
                    category: category,
                    assignedTo: assignee
                )
            }
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(choreType.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if !choreType.description.isEmpty {
                        Text(choreType.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let dur = choreType.durationDisplay {
                        Text(dur)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.06), in: Capsule())
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
