import SwiftUI

private enum TabMode: String, CaseIterable {
    case notes = "Notes"
    case bugs = "Bugs"
}

struct NotesTabView: View {
    @Bindable var viewModel: NotesViewModel
    @Bindable var bugReportsViewModel: BugReportsViewModel
    @Binding var showingProfile: Bool
    @State private var noteToDelete: Note?
    @State private var bugToDelete: BugReport?
    @State private var mode: TabMode = .notes

    private static let timestampFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented toggle
                Picker("Mode", selection: $mode) {
                    ForEach(TabMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Group {
                    if mode == .notes {
                        notesContent
                    } else {
                        bugsContent
                    }
                }
            }
            .chooBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .opacity(0.6)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Notes")
                        .font(.system(.headline, design: .serif))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if mode == .notes {
                            viewModel.editingNote = nil
                            viewModel.showingNoteEditor = true
                        } else {
                            bugReportsViewModel.editingBugReport = nil
                            bugReportsViewModel.showingBugEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Notes sheet
            .sheet(isPresented: $viewModel.showingNoteEditor) {
                NoteEditorView(existingNote: viewModel.editingNote) { title, content, isList in
                    if let noteId = viewModel.editingNote?.id {
                        await viewModel.updateNote(noteId: noteId, title: title, content: content)
                    } else {
                        await viewModel.createNote(title: title, content: content, isList: isList)
                    }
                }
                .presentationBackground(.ultraThinMaterial)
            }
            // Bug report sheet
            .sheet(isPresented: $bugReportsViewModel.showingBugEditor) {
                BugReportEditorView(existingReport: bugReportsViewModel.editingBugReport) { title, description, severity in
                    await bugReportsViewModel.createBugReport(title: title, description: description, severity: severity)
                }
                .presentationBackground(.ultraThinMaterial)
            }
            // Note delete confirmation
            .confirmationDialog(
                "Delete \"\(noteToDelete?.title ?? "")\"?",
                isPresented: Binding(
                    get: { noteToDelete != nil },
                    set: { if !$0 { noteToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete {
                        Task { await viewModel.deleteNote(note) }
                        noteToDelete = nil
                    }
                }
            }
            // Bug delete confirmation
            .confirmationDialog(
                "Delete \"\(bugToDelete?.title ?? "")\"?",
                isPresented: Binding(
                    get: { bugToDelete != nil },
                    set: { if !$0 { bugToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let bug = bugToDelete {
                        Task { await bugReportsViewModel.deleteBugReport(bug) }
                        bugToDelete = nil
                    }
                }
            }
        }
    }

    // MARK: - Notes Content

    @ViewBuilder
    private var notesContent: some View {
        if viewModel.notes.isEmpty {
            ContentUnavailableView(
                "No Notes",
                systemImage: "note.text",
                description: Text("Tap + to create your first note.")
            )
        } else {
            List {
                ForEach(viewModel.notes) { note in
                    Button {
                        viewModel.editingNote = note
                        viewModel.showingNoteEditor = true
                    } label: {
                        noteRow(note)
                    }
                    .tint(.primary)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.thinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .padding(.vertical, 4)
                    )
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        noteToDelete = viewModel.notes[index]
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Bugs Content

    @ViewBuilder
    private var bugsContent: some View {
        if bugReportsViewModel.bugReports.isEmpty {
            ContentUnavailableView(
                "No Bug Reports",
                systemImage: "ladybug",
                description: Text("Tap + to report a bug.")
            )
        } else {
            List {
                ForEach(bugReportsViewModel.bugReports) { report in
                    Button {
                        bugReportsViewModel.editingBugReport = report
                        bugReportsViewModel.showingBugEditor = true
                    } label: {
                        bugRow(report)
                    }
                    .tint(.primary)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.thinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .padding(.vertical, 4)
                    )
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        bugToDelete = bugReportsViewModel.bugReports[index]
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Note Row

    private func noteRow(_ note: Note) -> some View {
        HStack(spacing: 12) {
            Image(systemName: note.isList == true ? "checklist" : "note.text")
                .foregroundStyle(.secondary)
                .imageScale(.large)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)

                if !note.content.isEmpty {
                    if note.isList == true {
                        listPreview(for: note.content)
                    } else {
                        Text(note.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                HStack {
                    Text(note.createdBy)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text(Self.timestampFormatter.localizedString(for: note.updatedAt, relativeTo: Date()))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bug Row

    private func bugRow(_ report: BugReport) -> some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(statusColor(report.statusEnum))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(report.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    // Severity pill
                    Text(report.severityEnum.displayName)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(severityColor(report.severityEnum).opacity(0.15))
                        .foregroundStyle(severityColor(report.severityEnum))
                        .clipShape(Capsule())
                }

                if !report.description.isEmpty {
                    Text(report.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    // Status label
                    Text(report.statusEnum.displayName)
                        .font(.caption)
                        .foregroundStyle(statusColor(report.statusEnum))

                    // GitHub link pill
                    if let num = report.githubIssueNumber {
                        Text("GH-\(num)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(report.createdBy)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(Self.timestampFormatter.localizedString(for: report.updatedAt, relativeTo: Date()))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func statusColor(_ status: BugStatus) -> Color {
        switch status {
        case .open: .orange
        case .inProgress: .blue
        case .fixed: .green
        case .closed: .gray
        }
    }

    private func severityColor(_ severity: BugSeverity) -> Color {
        switch severity {
        case .low: .gray
        case .medium: .orange
        case .high: .red
        }
    }

    @ViewBuilder
    private func listPreview(for content: String) -> some View {
        let items = ListItem.parse(content)
        let unchecked = items.filter { !$0.isChecked }
        let checked = items.filter(\.isChecked).count
        let total = items.count

        VStack(alignment: .leading, spacing: 2) {
            ForEach(unchecked.prefix(3)) { item in
                HStack(spacing: 4) {
                    Image(systemName: "circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if unchecked.count > 3 {
                Text("+\(unchecked.count - 3) more")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if checked > 0 {
                Text("\(checked)/\(total) done")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}
