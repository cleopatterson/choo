import SwiftUI

/// Form for adding or editing a supply item — matches SessionTypeFormSheet design.
struct SupplyItemFormSheet: View {
    let existingItem: SupplyItem?
    let onSave: (String, SupplyCategory, SupplyCadence, Int) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: SupplyCategory
    @State private var cadence: SupplyCadence
    @State private var aisleOrder: Int
    @State private var showingDeleteConfirmation = false

    private let aisles: [(value: Int, label: String)] = [
        (1, "Fruit & Veg"),
        (2, "Dairy"),
        (3, "Meat"),
        (4, "Deli & Bakery"),
        (5, "Pantry"),
        (6, "Breakfast & Bread"),
        (7, "Cleaning"),
    ]

    init(
        category: SupplyCategory,
        existingItem: SupplyItem? = nil,
        onSave: @escaping (String, SupplyCategory, SupplyCadence, Int) -> Void,
        onDelete: (() -> Void)?
    ) {
        self.existingItem = existingItem
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: existingItem?.name ?? "")
        _category = State(initialValue: existingItem?.category ?? category)
        _cadence = State(initialValue: existingItem?.cadence ?? .monthly)
        _aisleOrder = State(initialValue: existingItem?.aisleOrder ?? 5)
    }

    private var isCreate: Bool { existingItem == nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Form {
            // Item info
            Section {
                HStack(spacing: 10) {
                    Text(category.emoji)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(Color.chooAmber.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                    TextField("Item name", text: $name)
                        .font(.headline)
                }
            } header: {
                Text(category.displayName)
            }

            // Details
            Section("Details") {
                Picker("Category", selection: $category) {
                    ForEach(SupplyCategory.allCases, id: \.self) { cat in
                        HStack {
                            Text(cat.emoji)
                            Text(cat.displayName)
                        }
                        .tag(cat)
                    }
                }

                Picker("Cadence", selection: $cadence) {
                    ForEach(SupplyCadence.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                }

                Picker("Aisle", selection: $aisleOrder) {
                    ForEach(aisles, id: \.value) { aisle in
                        Text(aisle.label).tag(aisle.value)
                    }
                }
            }

            // Delete
            if let onDelete {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Supply")
                            Spacer()
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(isCreate ? "New Supply" : "Edit Supply")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed, category, cadence, aisleOrder)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .confirmationDialog("Delete this supply?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }
}
