import SwiftUI

struct ShareFormView: View {
    let initialText: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var content: String = ""

    private var isLoggedIn: Bool { SharedUserContext.isLoggedIn }

    var body: some View {
        NavigationStack {
            Form {
                if !isLoggedIn {
                    Section {
                        Label("Please open Choo and sign in first.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Title") {
                    TextField("Note title", text: $title)
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Save to Choo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, content)
                    }
                    .disabled(!isLoggedIn || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                prefill()
            }
        }
    }

    private func prefill() {
        let lines = initialText.components(separatedBy: .newlines)
        title = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if lines.count > 1 {
            content = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            content = initialText
        }
    }
}
