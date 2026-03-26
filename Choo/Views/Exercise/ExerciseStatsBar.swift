import SwiftUI

struct ExerciseStatsBar: View {
    var plannedMinutes: Int = 0
    var actualMinutes: Int = 0
    var averageSteps: Int = 0
    var totalCalories: Int = 0
    let targetMinutes: Int = 150

    private var totalMinutes: Int {
        max(actualMinutes, 0) + max(plannedMinutes, 0)
    }

    private var minutesColor: Color {
        totalMinutes >= targetMinutes ? Color(hex: "#00b894") : Color(hex: "#4ecdc4")
    }

    var body: some View {
        HStack(spacing: 0) {
            statChip(
                value: "\(totalMinutes)",
                label: "Min / \(targetMinutes)",
                accent: minutesColor
            )

            divider

            statChip(
                value: formatNumber(averageSteps),
                label: "Avg steps",
                accent: Color(hex: "#f39c12")
            )

            divider

            statChip(
                value: formatNumber(totalCalories),
                label: "Cal burned",
                accent: Color(hex: "#ff6b6b")
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .frame(width: 1, height: 24)
    }

    private func statChip(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(accent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            let k = Double(n) / 1000.0
            return k.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(k))k" : String(format: "%.1fk", k)
        }
        return "\(n)"
    }
}
