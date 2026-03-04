import SwiftUI

struct MemberAvatarView: View {
    let name: String
    let uid: String
    var emoji: String? = nil
    var size: CGFloat = 28

    private static let colors: [Color] = [
        .red, .orange, .green, .blue, .purple, .pink, .mint, .teal, .cyan, .indigo
    ]

    /// Deterministic color from UID using a better hash to avoid collisions.
    static func color(for uid: String) -> Color {
        var hash: UInt64 = 5381
        for byte in uid.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte) // djb2
        }
        return colors[Int(hash % UInt64(colors.count))]
    }

    private var color: Color {
        Self.color(for: uid)
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            if let emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.55))
            } else {
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
