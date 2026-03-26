import SwiftUI

struct HouseChoreTypeFormSheet: View {
    let category: ChoreCategory
    let existingType: ChoreType?
    let onSave: (String, String, Int?, ChoreFrequency) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var durationMinutes: Int
    @State private var frequency: ChoreFrequency

    init(
        category: ChoreCategory,
        existingType: ChoreType? = nil,
        onSave: @escaping (String, String, Int?, ChoreFrequency) async -> Void
    ) {
        self.category = category
        self.existingType = existingType
        self.onSave = onSave
        _name = State(initialValue: existingType?.name ?? "")
        _description = State(initialValue: existingType?.description ?? "")
        _durationMinutes = State(initialValue: existingType?.durationMinutes ?? 0)
        _frequency = State(initialValue: existingType?.effectiveFrequency ?? .weekly)
    }

    private var isCreate: Bool { existingType == nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Text(category.emoji)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: category.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                        TextField("Chore name", text: $name)
                            .font(.headline)
                    }

                    TextField("Description (optional)", text: $description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(category.name)
                }

                Section("Details") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Stepper("\(durationMinutes) min", value: $durationMinutes, in: 0...480, step: 15)
                            .fixedSize()
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(ChoreFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(isCreate ? "New Chore Type" : "Edit Chore Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(
                                name,
                                description,
                                durationMinutes > 0 ? durationMinutes : nil,
                                frequency
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
}
