import SwiftUI

/// The holiday bleed: a soft wash + continuous left ribbon rendered as the
/// `listRowBackground` of every row on a day covered by a multi-day trip.
/// Consecutive rows tile into one continuous band because day spacing lives in
/// row insets (no section spacing between them).
struct TripWashBackground: View {
    let color: Color
    let position: TripSpanPosition
    /// The month hero keeps its own art mid-span — ribbon only, no tint.
    var tintVisible: Bool = true

    var body: some View {
        ZStack(alignment: .leading) {
            if tintVisible {
                LinearGradient(stops: tintStops, startPoint: .top, endPoint: .bottom)
            }

            Rectangle()
                .fill(LinearGradient(stops: ribbonStops, startPoint: .top, endPoint: .bottom))
                .frame(width: 3)
                .padding(.leading, 6)
        }
    }

    private var tintStops: [Gradient.Stop] {
        switch position {
        case .start:
            return [
                .init(color: .clear, location: 0),
                .init(color: color.opacity(0.09), location: 0.5),
                .init(color: color.opacity(0.08), location: 1)
            ]
        case .middle:
            return [
                .init(color: color.opacity(0.08), location: 0),
                .init(color: color.opacity(0.07), location: 1)
            ]
        case .end:
            return [
                .init(color: color.opacity(0.07), location: 0),
                .init(color: .clear, location: 1)
            ]
        }
    }

    private var ribbonStops: [Gradient.Stop] {
        switch position {
        case .start:
            return [
                .init(color: .clear, location: 0),
                .init(color: color.opacity(0.5), location: 0.6),
                .init(color: color.opacity(0.5), location: 1)
            ]
        case .middle:
            return [.init(color: color.opacity(0.5), location: 0), .init(color: color.opacity(0.5), location: 1)]
        case .end:
            return [
                .init(color: color.opacity(0.5), location: 0),
                .init(color: color.opacity(0.5), location: 0.4),
                .init(color: .clear, location: 1)
            ]
        }
    }
}
