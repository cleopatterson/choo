import SwiftUI

struct ExerciseAddSheet: View {
    @Bindable var viewModel: ExerciseViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimeSlot: TimeSlot = .morning
    @State private var selectedCategory: ExerciseCategory?
    @State private var step: Step = .pickCategory
    @State private var capturedDayIndex: Int = 0

    private enum Step {
        case pickCategory
        case pickSession
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
                case .pickSession:
                    sessionStep
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle(step == .pickCategory ? "Add Session" : "Pick a Session")
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
        }
    }

    // MARK: - Step 1: Pick Time + Category

    private var categoryStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time slot picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIME OF DAY")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    HStack(spacing: 10) {
                        ForEach(TimeSlot.allCases, id: \.self) { slot in
                            timeSlotPill(slot)
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
                                        step = .pickSession
                                    }
                                }
                        }

                        // Rest day option
                        restDayRow
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func timeSlotPill(_ slot: TimeSlot) -> some View {
        let isSelected = selectedTimeSlot == slot
        return Button {
            selectedTimeSlot = slot
        } label: {
            HStack(spacing: 4) {
                Text(slot.emoji)
                Text(slot.label)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: "#4ecdc4").opacity(0.15) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color(hex: "#4ecdc4").opacity(0.5) : .white.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .foregroundStyle(isSelected ? Color(hex: "#4ecdc4") : .secondary)
        }
    }

    private func categoryRow(_ category: ExerciseCategory) -> some View {
        HStack(spacing: 12) {
            Text(category.emoji)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color(hex: category.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                Text(category.sessionTypes.map(\.name).joined(separator: ", "))
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

    private var restDayRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await viewModel.toggleRestDay(dayIndex)
            }
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text("😴")
                    .font(.title3)
                    .frame(width: 36, height: 36)

                Text("Rest Day")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
    }

    // MARK: - Step 2: Pick Session Type

    private var sessionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Back button
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
                    .foregroundStyle(Color(hex: "#4ecdc4"))
                }
                .padding(.horizontal)

                if let category = selectedCategory {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pick a \(category.name) session")
                            .font(.headline)
                        Text("For \(dayLabel) \(selectedTimeSlot.label.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(category.sessionTypes) { sessionType in
                            sessionTypeRow(sessionType, category: category)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func sessionTypeRow(_ sessionType: SessionType, category: ExerciseCategory) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await viewModel.assignSession(
                    dayIndex: dayIndex,
                    timeSlot: selectedTimeSlot,
                    sessionType: sessionType,
                    category: category
                )
            }
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sessionType.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if !sessionType.description.isEmpty {
                        Text(sessionType.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Metadata badges
                    HStack(spacing: 6) {
                        if let dur = sessionType.durationDisplay {
                            metaBadge(text: dur)
                        }
                        if let cal = sessionType.estimatedCalories, cal > 0 {
                            metaBadge(text: "~\(cal) cal")
                        }
                        if let intensity = sessionType.intensityEnum {
                            Text("⚡ \(intensity.displayName)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(intensityColor(intensity))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(intensityColor(intensity).opacity(0.15), in: Capsule())
                        }
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

    private func metaBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white.opacity(0.06), in: Capsule())
    }

    private func intensityColor(_ intensity: ExerciseIntensity) -> Color {
        switch intensity {
        case .light: Color(red: 0.0, green: 0.72, blue: 0.58)
        case .moderate: Color(red: 0.99, green: 0.80, blue: 0.43)
        case .high: Color(red: 0.95, green: 0.57, blue: 0.24)
        case .peak: Color(red: 1.0, green: 0.42, blue: 0.42)
        }
    }
}
