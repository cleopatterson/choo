import SwiftUI

struct EventDetailView: View {
    let initialEvent: FamilyEvent
    @Bindable var viewModel: CalendarViewModel
    let occurrenceDay: Date
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showConfetti = false

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Live event from Firestore (updates when attendance changes).
    private var event: FamilyEvent {
        viewModel.firestoreService.events.first { $0.id == initialEvent.id } ?? initialEvent
    }

    private var isBillPaid: Bool {
        event.isPaidOn(occurrenceDay)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if event.isTodo == true {
                        LabeledContent("Start Date", value: Self.dateOnlyFormatter.string(from: event.startDate))

                        if event.todoHasDueDate {
                            LabeledContent("Due Date", value: Self.dateOnlyFormatter.string(from: event.endDate))
                        }

                        if let emoji = event.todoEmoji, !emoji.isEmpty {
                            LabeledContent("Emoji", value: emoji)
                        }

                        LabeledContent {
                            let state = event.urgencyState
                            HStack(spacing: 4) {
                                Text(todoStatusLabel(state))
                                    .foregroundStyle(todoStatusColor(state))
                            }
                        } label: {
                            Label("Status", systemImage: event.isCompleted == true ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(event.isCompleted == true ? .green : .secondary)
                        }
                    } else if event.isBill == true {
                        LabeledContent("Due Date", value: Self.dateOnlyFormatter.string(from: event.startDate))

                        if let amt = event.amount {
                            LabeledContent {
                                Text(amt, format: .currency(code: "AUD"))
                            } label: {
                                Label("Amount", systemImage: "dollarsign.circle.fill")
                            }
                        }

                        if let note = event.note, !note.isEmpty {
                            LabeledContent {
                                Text(note)
                            } label: {
                                Label("Note", systemImage: "text.quote")
                            }
                        }

                        LabeledContent {
                            Text(isBillPaid ? "Paid" : "Unpaid")
                                .foregroundStyle(isBillPaid ? .green : .secondary)
                        } label: {
                            Label("Status", systemImage: isBillPaid ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isBillPaid ? .green : .secondary)
                        }
                    } else if event.isAllDay == true {
                        let startDay = Self.dateOnlyFormatter.string(from: event.startDate)
                        let endDay = Self.dateOnlyFormatter.string(from: event.endDate)
                        LabeledContent("Date", value: startDay)
                        if !Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
                            LabeledContent("End Date", value: endDay)
                        }
                    } else {
                        LabeledContent("Date & Time", value: Self.dateTimeFormatter.string(from: event.startDate))
                    }

                    if event.isBill != true, let location = event.location, !location.isEmpty {
                        LabeledContent {
                            Text(location)
                        } label: {
                            Label("Location", systemImage: "mappin")
                        }
                    }

                    if let freq = event.recurrence {
                        LabeledContent {
                            Text(freq.displayName)
                        } label: {
                            Label("Repeats", systemImage: "repeat")
                        }

                        if let recEnd = event.recurrenceEndDate {
                            LabeledContent("Until", value: Self.dateOnlyFormatter.string(from: recEnd))
                        }
                    }

                    if event.reminderEnabled == true {
                        LabeledContent {
                            Text((event.isBill == true || event.isAllDay == true) ? "9 AM on the day" : "15 min before")
                        } label: {
                            Label("Reminder", systemImage: "bell.fill")
                        }
                    }
                }

                if event.isBill != true {
                    let attendeeUIDs = event.attendeeUIDs ?? []
                    let goingMembers = viewModel.allMembers.filter { attendeeUIDs.contains($0.id) }
                    if !goingMembers.isEmpty {
                        Section("Who's Going") {
                            ForEach(goingMembers) { member in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    Task { await viewModel.toggleAttendance(event: event, uid: member.id) }
                                } label: {
                                    HStack {
                                        MemberAvatarView(name: member.displayName, uid: member.id, emoji: member.emoji)
                                        Text(member.displayName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .imageScale(.large)
                                    }
                                }
                                .tint(.primary)
                            }
                        }
                    }
                }

                if event.isTodo == true {
                    Section {
                        Button {
                            let isCurrentlyDone = event.isCompleted == true
                            if !isCurrentlyDone {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                showConfetti = true
                            }
                            Task {
                                await viewModel.toggleTodoCompleted(event)
                                if !isCurrentlyDone {
                                    try? await Task.sleep(for: .seconds(2.0))
                                    showConfetti = false
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label(
                                    event.isCompleted == true ? "Mark as Incomplete" : "Mark as Done",
                                    systemImage: event.isCompleted == true ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill"
                                )
                                .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .tint(event.isCompleted == true ? .orange : .green)
                    }
                } else if event.isBill == true {
                    Section {
                        Button {
                            if !isBillPaid {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                showConfetti = true
                            }
                            Task {
                                await viewModel.toggleBillPaid(event, on: occurrenceDay)
                                if !isBillPaid {
                                    try? await Task.sleep(for: .seconds(2.0))
                                    showConfetti = false
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label(
                                    isBillPaid ? "Mark as Unpaid" : "Mark as Paid",
                                    systemImage: isBillPaid ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill"
                                )
                                .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .tint(isBillPaid ? .orange : .green)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label({
                                if event.isTodo == true { return "Delete To-Do" }
                                if event.isBill == true { return "Delete Bill" }
                                return "Delete Event"
                            }(), systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EventFormView(
                    familyMembers: viewModel.allMembers,
                    currentUserUID: viewModel.currentUserUID,
                    initialDate: event.startDate,
                    existingEvent: event
                ) { title, start, end, attendees, isAllDay, location, recurrenceFrequency, recurrenceEndDate, reminderEnabled, isBill, amount, note, isTodo, todoEmoji in
                    var updated = FamilyEvent(
                        familyId: event.familyId,
                        title: title,
                        startDate: start,
                        endDate: end,
                        createdBy: event.createdBy,
                        attendeeUIDs: attendees,
                        isAllDay: isAllDay,
                        location: location,
                        recurrenceFrequency: recurrenceFrequency,
                        recurrenceEndDate: recurrenceEndDate,
                        reminderEnabled: reminderEnabled,
                        isBill: isBill,
                        amount: amount,
                        isPaid: event.isPaid,
                        paidOccurrences: event.paidOccurrences,
                        note: note,
                        isTodo: isTodo,
                        isCompleted: event.isCompleted,
                        completedDate: event.completedDate,
                        todoEmoji: todoEmoji
                    )
                    updated.id = event.id
                    await viewModel.updateEvent(updated)
                }
                .presentationBackground(.ultraThinMaterial)
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                }
            }
            .confirmationDialog({
                if event.isTodo == true { return "Delete this to-do?" }
                if event.isBill == true { return "Delete this bill?" }
                return "Delete this event?"
            }(), isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteEvent(event)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func todoStatusLabel(_ state: TodoUrgencyState) -> String {
        switch state {
        case .done: "Done"
        case .overdue: "Overdue"
        case .dueSoon: "Due Soon"
        case .active: "Active"
        case .flexible: "Flexible"
        case .notStarted: "Not Started"
        }
    }

    private func todoStatusColor(_ state: TodoUrgencyState) -> Color {
        switch state {
        case .done: .green
        case .overdue: .red
        case .dueSoon: .orange
        case .active: .cyan
        case .flexible: .secondary
        case .notStarted: .secondary
        }
    }
}
