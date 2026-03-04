import SwiftUI

/// Reusable form for adding or editing a session type with duration, calories, and intensity.
struct SessionTypeFormSheet: View {
    let category: ExerciseCategory
    let existingType: SessionType?
    let onSave: (String, String, Int?, Int?, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var durationMinutes: Int
    @State private var estimatedCalories: Int
    @State private var selectedIntensity: ExerciseIntensity?

    init(
        category: ExerciseCategory,
        existingType: SessionType? = nil,
        onSave: @escaping (String, String, Int?, Int?, String?) async -> Void
    ) {
        self.category = category
        self.existingType = existingType
        self.onSave = onSave
        _name = State(initialValue: existingType?.name ?? "")
        _description = State(initialValue: existingType?.description ?? "")
        _durationMinutes = State(initialValue: existingType?.durationMinutes ?? 0)
        _estimatedCalories = State(initialValue: existingType?.estimatedCalories ?? 0)
        _selectedIntensity = State(initialValue: existingType?.intensityEnum)
    }

    private var isCreate: Bool { existingType == nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // Session info
                Section {
                    HStack(spacing: 10) {
                        Text(category.emoji)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: category.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                        TextField("Session name", text: $name)
                            .font(.headline)
                    }

                    TextField("Description (optional)", text: $description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(category.name)
                }

                // Details
                Section("Details") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Stepper("\(durationMinutes) min", value: $durationMinutes, in: 0...240, step: 5)
                            .fixedSize()
                    }

                    HStack {
                        Text("Est. Calories")
                        Spacer()
                        Stepper("~\(estimatedCalories) cal", value: $estimatedCalories, in: 0...1500, step: 10)
                            .fixedSize()
                    }

                    Picker("Intensity", selection: $selectedIntensity) {
                        Text("Not set").tag(ExerciseIntensity?.none)
                        ForEach(ExerciseIntensity.allCases) { intensity in
                            HStack {
                                Text("⚡ \(intensity.displayName)")
                                Text("– \(intensity.subtitle)")
                                    .foregroundStyle(.secondary)
                            }
                            .tag(ExerciseIntensity?.some(intensity))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(isCreate ? "New Session Type" : "Edit Session Type")
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
                                estimatedCalories > 0 ? estimatedCalories : nil,
                                selectedIntensity?.rawValue
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
