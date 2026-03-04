import SwiftUI

struct BriefingCardView: View {
    let badge: String
    let dateRange: String
    let headline: String
    let summary: String
    let accent: TabAccent
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("✦ \(badge) · \(dateRange)")
                .font(.caption.bold())
                .foregroundStyle(accent.color.opacity(0.65))
                .tracking(1.5)

            Text(headline)
                .font(.system(.title2, design: .serif).bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            if !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.08, blue: 0.28),
                        Color(red: 0.16, green: 0.10, blue: 0.35),
                        Color(red: 0.08, green: 0.12, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [accent.color.opacity(0.15), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 200
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay { shimmer }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @ViewBuilder
    private var shimmer: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.1))
                .frame(width: 120, height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.08))
                .frame(height: 20)
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.06))
                .frame(width: 200, height: 14)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
