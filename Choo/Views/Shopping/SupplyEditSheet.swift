import SwiftUI

struct SupplyEditSheet: View {
    let item: SupplyItem?  // nil = adding new
    let onSave: (String, SupplyCategory, SupplyCadence, Int) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var name: String
    @State private var category: SupplyCategory
    @State private var cadence: SupplyCadence
    @State private var aisleOrder: Int

    private let aisles: [(value: Int, label: String)] = [
        (1, "1 · Fruit & Veg"),
        (2, "2 · Dairy"),
        (3, "3 · Meat"),
        (4, "4 · Deli & Bakery"),
        (5, "5 · Pantry"),
        (6, "6 · Breakfast & Bread"),
        (7, "7 · Cleaning"),
    ]

    init(item: SupplyItem?, onSave: @escaping (String, SupplyCategory, SupplyCadence, Int) -> Void, onDelete: (() -> Void)?, onCancel: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _name = State(initialValue: item?.name ?? "")
        _category = State(initialValue: item?.category ?? .pantry)
        _cadence = State(initialValue: item?.cadence ?? .monthly)
        _aisleOrder = State(initialValue: item?.aisleOrder ?? 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(item == nil ? "Add Supply" : item!.name)
                    .font(.headline.weight(.heavy))
                Spacer()
                if let onDelete {
                    Button {
                        onDelete()
                    } label: {
                        Text("Delete")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
            }

            // Name
            sectionLabel("Name")
            TextField("Item name", text: $name)
                .padding(11)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.08)))

            // Cadence
            sectionLabel("Cadence")
            pillPicker(values: SupplyCadence.allCases, selected: cadence, label: \.displayName) { cadence = $0 }

            // Category
            sectionLabel("Category")
            pillPicker(values: SupplyCategory.allCases, selected: category, label: { "\($0.emoji) \($0.displayName)" }) { category = $0 }

            // Aisle
            sectionLabel("Run aisle")
            FlowLayout(spacing: 8) {
                ForEach(aisles, id: \.value) { aisle in
                    pillButton(aisle.label, selected: aisleOrder == aisle.value) {
                        aisleOrder = aisle.value
                    }
                }
            }

            // Save
            Button {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSave(trimmed, category, cadence, aisleOrder)
            } label: {
                Text("Save")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.chooAmber)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(0.4)
    }

    private func pillPicker<T: Hashable>(values: [T], selected: T, label: @escaping (T) -> String, action: @escaping (T) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(values, id: \T.self) { value in
                pillButton(label(value), selected: selected == value) {
                    action(value)
                }
            }
        }
    }

    private func pillPicker<T: Hashable>(values: [T], selected: T, label: KeyPath<T, String>, action: @escaping (T) -> Void) -> some View {
        pillPicker(values: values, selected: selected, label: { $0[keyPath: label] }, action: action)
    }

    private func pillButton(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(selected ? Color.chooAmber.opacity(0.15) : Color.white.opacity(0.05))
                .overlay(
                    Capsule().strokeBorder(selected ? Color.chooAmber : Color.white.opacity(0.08), lineWidth: 1.5)
                )
                .clipShape(Capsule())
                .foregroundStyle(selected ? Color.chooAmber : .secondary)
        }
        .buttonStyle(.plain)
    }
}
