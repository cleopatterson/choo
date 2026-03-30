import SwiftUI

// MARK: - Assign Sheet (tap)

struct HouseChoreActionSheet: View {
    @Bindable var viewModel: HouseViewModel
    let item: HouseViewModel.HouseDueItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Info row
                    HStack(spacing: 10) {
                        Text(item.categoryEmoji)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.categoryName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let last = item.lastCompleted {
                                Text("Last done \(relativeDate(last))")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.4))
                            } else {
                                Text("Never completed")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }

                    // Day picker
                    Picker("Day", selection: Binding<Int>(
                        get: { item.plannedDay ?? -1 },
                        set: { newValue in
                            Task {
                                if newValue == -1 {
                                    await viewModel.unplanChore(item.choreType.id)
                                } else {
                                    await viewModel.planChoreToDay(item.choreType.id, dayIndex: newValue)
                                }
                            }
                        }
                    )) {
                        Text("None").tag(-1)
                        ForEach(Array(viewModel.weekDays.enumerated()), id: \.offset) { index, date in
                            if !viewModel.isPast(date) {
                                Text(viewModel.dayAbbreviation(for: date)).tag(index)
                            }
                        }
                    }

                    // Assign to
                    if !viewModel.availableAssignees.isEmpty {
                        Picker("Assign to", selection: Binding<String>(
                            get: { item.assignedTo ?? "" },
                            set: { newValue in
                                Task {
                                    if newValue.isEmpty {
                                        await viewModel.unassignChore(item.choreType.id)
                                    } else {
                                        await viewModel.assignChore(item.choreType.id, to: newValue)
                                    }
                                }
                            }
                        )) {
                            Text("Unassigned").tag("")
                            ForEach(viewModel.availableAssignees) { assignee in
                                Text("\(assignee.emoji) \(assignee.displayName)").tag(assignee.id)
                            }
                        }
                    }
                }

                // Mark as done
                Section {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task {
                            await viewModel.completeChore(
                                item.choreType.id,
                                choreTypeName: item.choreType.name,
                                categoryName: item.categoryName
                            )
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Mark as Done", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: "#00b894"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(item.choreType.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func assigneeIcon(_ assignee: ChoreAssignee) -> some View {
        if assignee.emoji.count == 1 && assignee.emoji.first?.isLetter == true {
            // Initial letter badge
            Text(assignee.emoji)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color(hex: assignee.colorHex))
                .clipShape(Circle())
        } else {
            Text(assignee.emoji)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days) days ago" }
        let weeks = days / 7
        if weeks < 5 { return "\(weeks) week\(weeks == 1 ? "" : "s") ago" }
        let months = days / 30
        return "\(months) month\(months == 1 ? "" : "s") ago"
    }
}

// MARK: - Edit Sheet (long-press)

struct HouseChoreEditSheet: View {
    @Bindable var viewModel: HouseViewModel
    let item: HouseViewModel.HouseDueItem
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedFrequency: ChoreFrequency
    @State private var showingDeleteConfirmation = false

    init(viewModel: HouseViewModel, item: HouseViewModel.HouseDueItem) {
        self.viewModel = viewModel
        self.item = item
        _name = State(initialValue: item.choreType.name)
        _selectedFrequency = State(initialValue: item.choreType.effectiveFrequency)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }

                Section {
                    Picker("Frequency", selection: $selectedFrequency) {
                        ForEach(ChoreFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Chore", systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog("Delete \"\(item.choreType.name)\"?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        guard let category = viewModel.categories.first(where: { $0.choreTypes.contains(where: { $0.id == item.id }) }) else { return }
                        await viewModel.deleteChoreType(from: category, typeId: item.id)
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if selectedFrequency != item.choreType.effectiveFrequency {
            Task { await viewModel.updateChoreFrequency(item.choreType.id, frequency: selectedFrequency) }
        }

        if trimmedName != item.choreType.name {
            Task {
                guard let category = viewModel.categories.first(where: { $0.choreTypes.contains(where: { $0.id == item.id }) }) else { return }
                await viewModel.updateChoreType(
                    in: category,
                    typeId: item.choreType.id,
                    name: trimmedName,
                    description: item.choreType.description,
                    durationMinutes: item.choreType.durationMinutes,
                    frequency: selectedFrequency
                )
            }
        }
    }
}
