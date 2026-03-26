import SwiftUI

struct HouseDayPlanSheet: View {
    @Bindable var viewModel: HouseViewModel
    let dayIndex: Int
    @Environment(\.dismiss) private var dismiss

    private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    private var dayLabel: String {
        guard dayIndex < viewModel.weekDays.count else { return "" }
        return Self.dayLabelFormatter.string(from: viewModel.weekDays[dayIndex])
    }

    private var plannedChores: [HouseViewModel.HouseDueItem] {
        viewModel.choresForDay(dayIndex)
    }

    private var unplannedDueChores: [HouseViewModel.HouseDueItem] {
        viewModel.dueItems.filter { $0.plannedDay == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Already planned for this day
                    if !plannedChores.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PLANNED FOR \(dayLabel.uppercased())")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .tracking(1)

                            ForEach(plannedChores) { item in
                                plannedRow(item)
                            }
                        }
                    }

                    // Due chores to add
                    if !unplannedDueChores.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ADD TO \(dayLabel.uppercased())")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .tracking(1)

                            ForEach(unplannedDueChores) { item in
                                addRow(item)
                            }
                        }
                    }

                    if plannedChores.isEmpty && unplannedDueChores.isEmpty {
                        VStack(spacing: 12) {
                            Text("\u{2728}")
                                .font(.system(size: 40))
                            Text("Nothing due right now")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .background(.ultraThinMaterial)
            .navigationTitle(dayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func plannedRow(_ item: HouseViewModel.HouseDueItem) -> some View {
        HStack(spacing: 10) {
            Text(item.categoryEmoji)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.choreType.name)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 6) {
                    Text(item.categoryName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let assigneeId = item.assignedTo,
                       let person = viewModel.assignee(for: assigneeId) {
                        Text(person.displayName)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: person.colorHex))
                    }
                }
            }

            Spacer()

            Button {
                Task { await viewModel.unplanChore(item.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.chooRose.opacity(0.15), lineWidth: 1)
        )
    }

    private func addRow(_ item: HouseViewModel.HouseDueItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await viewModel.planChoreToDay(item.id, dayIndex: dayIndex) }
        } label: {
            HStack(spacing: 10) {
                Text(item.categoryEmoji)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.choreType.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(item.categoryName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if item.isOverdue {
                            Text("Overdue")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#ef4444"))
                        }
                    }
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.body)
                    .foregroundStyle(Color.chooRose)
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
