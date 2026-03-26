import SwiftUI

struct HeroCardView<Pills: View>: View {
    let label: String
    let title: String
    let subtitle: String
    let emoji: String
    let accent: TabAccent
    var isEmpty: Bool = false
    var emptyMessage: String = ""
    var emptyEmoji: String? = nil
    var emojiSize: CGFloat = 42
    @ViewBuilder var pills: () -> Pills

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEmpty {
                emptyState
            } else {
                filledState
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: accent.heroGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RadialGradient(
                    colors: [accent.color.opacity(0.2), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 200
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accent.color.opacity(0.35), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                bobOffset = 6
            }
        }
        .onDisappear {
            bobOffset = 0
        }
    }

    @ViewBuilder
    private var filledState: some View {
        Text(label)
            .font(.caption.bold())
            .foregroundStyle(accent.color.opacity(0.8))
            .tracking(1.5)

        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text(emoji)
                .font(.system(size: emojiSize))
                .fixedSize()
                .offset(y: -bobOffset)
        }

        HStack(spacing: 8) {
            pills()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var emptyState: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(accent.color.opacity(0.6))
                    .tracking(1.5)

                Text(emptyMessage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            if let emptyEmoji {
                Text(emptyEmoji)
                    .font(.system(size: 42))
                    .fixedSize()
                    .offset(y: -bobOffset)
            } else {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }

    static func pillBadge(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.1), in: Capsule())
    }

    /// Colored pill with tinted background — used for cuisine, effort, richness, category, etc.
    static func coloredPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    /// Neutral surface pill — used for carb type
    static func surfacePill(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.06), in: Capsule())
    }
}
