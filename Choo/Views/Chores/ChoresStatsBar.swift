import SwiftUI

struct ChoresStatsBar: View {
    let choreCount: Int
    let completedCount: Int
    let totalMinutes: Int

    var body: some View {
        HStack(spacing: 16) {
            statChip(value: "\(choreCount)", label: "Chore\(choreCount == 1 ? "" : "s")", accent: Color.chooCoral)
            statChip(value: "\(completedCount)", label: "Done", accent: completedCount > 0 ? Color(hex: "#00b894") : nil)
            if totalMinutes > 0 {
                let hrs = totalMinutes / 60
                let mins = totalMinutes % 60
                let durText = hrs > 0 ? (mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h") : "\(mins)m"
                statChip(value: durText, label: "Total", accent: nil)
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
