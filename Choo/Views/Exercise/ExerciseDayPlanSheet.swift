import SwiftUI

struct ExerciseDayPlanSheet: View {
    @Bindable var viewModel: ExerciseViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var capturedDayIndex: Int = 0
    @State private var pickingSlot: TimeSlot?
    @State private var pickingCategory: ExerciseCategory?

    private var dayIndex: Int { capturedDayIndex }

    private var dayLabel: String {
        guard dayIndex < viewModel.weekDays.count else { return "" }
        return Self.dayFormatter.string(from: viewModel.weekDays[dayIndex])
    }

    private var isRest: Bool {
        viewModel.restDays.contains(dayIndex)
    }

    private var sessions: [(timeSlot: TimeSlot, assignment: ExerciseSlotAssignment)] {
        viewModel.sessionsForDay(dayIndex)
    }

    var body: some View {
        NavigationStack {
            if let slot = pickingSlot {
                if let category = pickingCategory {
                    // Step 3: Pick session type
                    sessionPickerStep(slot: slot, category: category)
                } else {
                    // Step 2: Pick category for a slot
                    categoryPickerStep(slot: slot)
                }
            } else {
                // Step 1: Day overview with slots
                dayOverview
            }
        }
        .onAppear {
            capturedDayIndex = viewModel.selectedDayIndex ?? 0
        }
    }

    // MARK: - Day Overview

    private var dayOverview: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(TimeSlot.allCases, id: \.self) { slot in
                    slotCard(slot)
                }

                Divider().overlay(.white.opacity(0.06)).padding(.vertical, 4)

                // Rest day toggle
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await viewModel.toggleRestDay(dayIndex) }
                    if !isRest {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("😴")
                            .font(.title3)
                            .frame(width: 36, height: 36)

                        Text(isRest ? "Unmark Rest Day" : "Mark as Rest Day")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isRest ? Color.primary : Color.white.opacity(0.5))

                        Spacer()

                        if isRest {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.chooTeal)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isRest ? Color.chooTeal.opacity(0.3) : .white.opacity(0.06),
                                style: StrokeStyle(lineWidth: 1, dash: isRest ? [] : [6, 4])
                            )
                    )
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .navigationTitle(dayLabel)
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

    // MARK: - Slot Card

    @ViewBuilder
    private func slotCard(_ slot: TimeSlot) -> some View {
        let assignment = viewModel.slots[viewModel.slotKey(day: dayIndex, timeSlot: slot)]

        VStack(alignment: .leading, spacing: 0) {
            // Slot header
            Text(slot.label.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if isRest {
                // Rest day — dimmed
                HStack(spacing: 10) {
                    Text("😴")
                        .font(.subheadline)
                        .frame(width: 22)
                    Text("Rest")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else if let assignment {
                // Filled slot — tap to change
                HStack(spacing: 10) {
                    // Tappable session info area
                    HStack(spacing: 10) {
                        Text(assignment.categoryEmoji)
                            .font(.subheadline)
                            .frame(width: 22)

                        Text(assignment.sessionTypeName)
                            .font(.subheadline.weight(.semibold))

                        if let dur = assignment.durationMinutes, dur > 0 {
                            Text("\(dur) min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        pickingSlot = slot
                    }

                    // Clear button — outside tap gesture area
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await viewModel.clearSlot(dayIndex: dayIndex, timeSlot: slot) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                // Empty slot — tap to add
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    pickingSlot = slot
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption2)
                        Text("Add session")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    assignment != nil ? Color(hex: assignment!.categoryColorHex).opacity(0.2) : .white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Step 2: Category Picker

    private func categoryPickerStep(slot: TimeSlot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    pickingSlot = nil
                    pickingCategory = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.chooTeal)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick a category")
                        .font(.headline)
                    Text("For \(dayLabel) \(slot.label.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    ForEach(viewModel.categories) { category in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            pickingCategory = category
                        } label: {
                            HStack(spacing: 12) {
                                Text(category.emoji)
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: category.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                                Text(category.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(.ultraThinMaterial)
        .navigationTitle("Add Session")
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

    // MARK: - Step 3: Session Type Picker

    private func sessionPickerStep(slot: TimeSlot, category: ExerciseCategory) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    pickingCategory = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.chooTeal)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick a \(category.name) session")
                        .font(.headline)
                    Text("For \(dayLabel) \(slot.label.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    ForEach(category.sessionTypes) { sessionType in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                await viewModel.assignSession(
                                    dayIndex: dayIndex,
                                    timeSlot: slot,
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
                            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(.ultraThinMaterial)
        .navigationTitle("Pick a Session")
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

    // MARK: - Helpers

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

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}
