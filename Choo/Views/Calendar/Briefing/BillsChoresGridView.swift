import SwiftUI

struct BillsChoresGridView: View {
    let bills: [BriefingBill]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        if bills.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("BILLS DUE")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(bills) { bill in
                        billCard(bill)
                    }
                }
                .padding(.horizontal, 20)
            }
        )
    }

    private func billCard(_ bill: BriefingBill) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title3)
                .foregroundStyle(bill.isPast ? .white.opacity(0.3) : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.title)
                    .font(.caption.bold())
                    .foregroundStyle(bill.isPast ? .white.opacity(0.35) : .white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let amount = bill.amount {
                        Text(amount, format: .currency(code: "AUD"))
                            .font(.caption2)
                            .foregroundStyle(bill.isPast ? .white.opacity(0.25) : .white.opacity(0.6))
                    }
                    Text(Self.shortDateFormatter.string(from: bill.date))
                        .font(.caption2)
                        .foregroundStyle(bill.isPast ? .white.opacity(0.25) : .white.opacity(0.4))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .opacity(bill.isPast ? 0.7 : 1)
    }
}
