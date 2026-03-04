import SwiftUI

struct NotesTabView: View {
    @Bindable var viewModel: NotesViewModel
    @Binding var showingProfile: Bool

    private static let timestampFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
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
                            for index in indexSet {
                                let note = viewModel.notes[index]
                                Task { await viewModel.deleteNote(note) }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
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
                        viewModel.editingNote = nil
                        viewModel.showingNoteEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
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
        }
    }

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

    @ViewBuilder
    private func listPreview(for content: String) -> some View {
        let items = ListItem.parse(content)
        let unchecked = items.filter { !$0.isChecked }
        let checked = items.filter(\.isChecked).count
        let total = items.count

        VStack(alignment: .leading, spacing: 2) {
            // Show first few unchecked items
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
