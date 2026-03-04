import SwiftUI

// MARK: - List Item Model

struct ListItem: Identifiable {
    let id = UUID()
    var text: String
    var isChecked: Bool

    static func parse(_ content: String) -> [ListItem] {
        let lines = content.components(separatedBy: "\n")
        var items: [ListItem] = []
        for line in lines {
            if line.hasPrefix("- [x] ") {
                items.append(ListItem(text: String(line.dropFirst(6)), isChecked: true))
            } else if line.hasPrefix("- [ ] ") {
                items.append(ListItem(text: String(line.dropFirst(6)), isChecked: false))
            } else if !line.isEmpty {
                items.append(ListItem(text: line, isChecked: false))
            }
        }
        return items
    }

    static func serialize(_ items: [ListItem]) -> String {
        items.map { item in
            item.isChecked ? "- [x] \(item.text)" : "- [ ] \(item.text)"
        }.joined(separator: "\n")
    }
}

// MARK: - Isolated List Item Row (avoids full-list re-renders)

private struct ListItemRowView: View {
    @Binding var item: ListItem

    var body: some View {
        HStack(spacing: 10) {
            Button {
                item.isChecked.toggle()
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                    .imageScale(.large)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            TextField("Item", text: $item.text, axis: .vertical)
                .lineLimit(1...10)
                .strikethrough(item.isChecked, color: .secondary)
                .foregroundStyle(item.isChecked ? .secondary : .primary)
        }
    }
}

// MARK: - Note Editor View

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let existingNote: Note?
    let onSave: (String, String, Bool) async -> Void

    @State private var title: String
    @State private var isList: Bool
    @State private var content: String
    @State private var listItems: [ListItem]
    @State private var newItemText = ""
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, newItem
    }

    private var isNewNote: Bool { existingNote == nil }

    init(existingNote: Note? = nil, onSave: @escaping (String, String, Bool) async -> Void) {
        self.existingNote = existingNote
        self.onSave = onSave

        let noteIsList = existingNote?.isList ?? false
        _title = State(initialValue: existingNote?.title ?? "")
        _isList = State(initialValue: noteIsList)

        if noteIsList {
            _content = State(initialValue: "")
            _listItems = State(initialValue: ListItem.parse(existingNote?.content ?? ""))
        } else {
            _content = State(initialValue: existingNote?.content ?? "")
            _listItems = State(initialValue: [])
        }
    }

    private var contentToSave: String {
        isList ? ListItem.serialize(listItems) : content
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .focused($focusedField, equals: .title)

                    if isNewNote {
                        Picker("Type", selection: $isList) {
                            Label("Note", systemImage: "note.text").tag(false)
                            Label("List", systemImage: "checklist").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if isList {
                    listSection
                } else {
                    noteSection
                }
            }
            .scrollContentBackground(.hidden)
            .chooBackground()
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationTitle(isNewNote ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .onAppear {
                if isNewNote {
                    focusedField = .title
                }
            }
        }
    }

    // MARK: - Note Mode

    private var noteSection: some View {
        Section("Content") {
            TextEditor(text: $content)
                .frame(minHeight: 200)
        }
    }

    // MARK: - List Mode

    private var listSection: some View {
        Section {
            ForEach($listItems) { $item in
                ListItemRowView(item: $item)
            }
            .onDelete { listItems.remove(atOffsets: $0) }
            .onMove { listItems.move(fromOffsets: $0, toOffset: $1) }

            addItemRow
        } header: {
            HStack {
                Text("Items")
                Spacer()
                if listItems.contains(where: \.isChecked) {
                    Button("Clear done") {
                        listItems.removeAll(where: \.isChecked)
                    }
                    .font(.caption)
                    .textCase(nil)
                }
            }
        }
    }

    private var addItemRow: some View {
        HStack(spacing: 10) {
            Button {
                addNewItem()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(newItemText.isEmpty ? Color.secondary : Color.green)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .disabled(newItemText.isEmpty)

            TextField("Add item", text: $newItemText)
                .focused($focusedField, equals: .newItem)
                .onSubmit {
                    addNewItem()
                }
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            listItems.append(ListItem(text: trimmed, isChecked: false))
            newItemText = ""
        }
        isSaving = true
        Task {
            await onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), contentToSave, isList)
            isSaving = false
            dismiss()
        }
    }

    private func addNewItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listItems.append(ListItem(text: trimmed, isChecked: false))
        newItemText = ""
        focusedField = .newItem
    }
}
