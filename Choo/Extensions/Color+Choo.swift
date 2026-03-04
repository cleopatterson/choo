import SwiftUI

extension Color {
    // Primary brand color — vivid purple #8B5CF6
    static let chooPurple = Color(red: 0.545, green: 0.361, blue: 0.965)

    // Lighter variant for backgrounds
    static let chooPurpleLight = Color(red: 0.651, green: 0.482, blue: 0.976)

    // Amber accent — Shopping / Dinner tab
    static let chooAmber = Color(hex: "#fb923c")

    // Teal accent — Exercise tab
    static let chooTeal = Color(hex: "#4ecdc4")

    // Coral accent — Chores tab
    static let chooCoral = Color(hex: "#f97066")

    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Choo Background Gradient

extension View {
    func chooBackground() -> some View {
        self.background {
            ZStack {
                // Base sweep: deep indigo to muted violet to dark teal
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.06, blue: 0.25),  // deep indigo
                        Color(red: 0.14, green: 0.08, blue: 0.30),  // muted violet
                        Color(red: 0.06, green: 0.10, blue: 0.22)   // dark teal
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Radial purple glow in the top-right corner
                RadialGradient(
                    colors: [
                        Color.chooPurple.opacity(0.25),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Glass Text Field Style

extension View {
    func glassField() -> some View {
        self
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
