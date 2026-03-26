import SwiftUI

struct HouseStatsBar: View {
    let dueCount: Int
    let completedCount: Int
    let overdueCount: Int

    var body: some View {
        HStack(spacing: 16) {
            statChip(value: "\(dueCount)", label: "Due", accent: Color.chooRose)
            statChip(value: "\(completedCount)", label: "This month", accent: completedCount > 0 ? Color(hex: "#00b894") : nil)
            if overdueCount > 0 {
                statChip(value: "\(overdueCount)", label: "Overdue", accent: Color(hex: "#ef4444"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statChip(value: String, label: String, accent: Color?) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(accent ?? .secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
