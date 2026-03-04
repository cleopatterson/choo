import SwiftUI

struct ExerciseStatsBar: View {
    let sessionCount: Int
    let categoryCount: Int
    let restDayCount: Int

    var body: some View {
        HStack(spacing: 16) {
            statChip(value: sessionCount, label: "Session\(sessionCount == 1 ? "" : "s")", accent: Color(hex: "#4ecdc4"))
            statChip(value: categoryCount, label: "Categor\(categoryCount == 1 ? "y" : "ies")", accent: nil)
            statChip(value: restDayCount, label: "Rest day\(restDayCount == 1 ? "" : "s")", accent: nil)
        }
        .frame(maxWidth: .infinity)
    }

    private func statChip(value: Int, label: String, accent: Color?) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.subheadline.bold())
                .foregroundStyle(accent ?? .secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
