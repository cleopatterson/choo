import SwiftUI

struct BugReportEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let existingReport: BugReport?
    let onSave: (String, String, BugSeverity) async -> Void

    @State private var title: String
    @State private var description: String
    @State private var severity: BugSeverity
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, description
    }

    private var isNew: Bool { existingReport == nil }

    init(existingReport: BugReport? = nil, onSave: @escaping (String, String, BugSeverity) async -> Void) {
        self.existingReport = existingReport
        self.onSave = onSave
        _title = State(initialValue: existingReport?.title ?? "")
        _description = State(initialValue: existingReport?.description ?? "")
        _severity = State(initialValue: existingReport?.severityEnum ?? .medium)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bug title", text: $title)
                        .focused($focusedField, equals: .title)
                }

                Section("Severity") {
                    Picker("Severity", selection: $severity) {
                        ForEach(BugSeverity.allCases) { sev in
                            Text(sev.displayName).tag(sev)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 150)
                        .focused($focusedField, equals: .description)
                }

                if let report = existingReport {
                    Section("Status") {
                        HStack {
                            statusDot(for: report.statusEnum)
                            Text(report.statusEnum.displayName)
                                .foregroundStyle(.secondary)
                        }

                        if let url = report.githubIssueUrl, let link = URL(string: url) {
                            Link(destination: link) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("GH-\(report.githubIssueNumber ?? 0)")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .chooBackground()
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationTitle(isNew ? "Report Bug" : "Bug Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if isNew {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") { save() }
                            .disabled(title.isEmpty || isSaving)
                    }
                }
            }
            .onAppear {
                if isNew { focusedField = .title }
            }
        }
    }

    @ViewBuilder
    private func statusDot(for status: BugStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 8, height: 8)
    }

    private func statusColor(_ status: BugStatus) -> Color {
        switch status {
        case .open: .orange
        case .inProgress: .blue
        case .fixed: .green
        case .closed: .gray
        }
    }

    private func save() {
        isSaving = true
        Task {
            await onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), description, severity)
            isSaving = false
            dismiss()
        }
    }
}
