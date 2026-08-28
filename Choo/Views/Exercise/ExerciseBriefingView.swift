import SwiftUI

struct ExerciseBriefingView: View {
    let headline: String
    let isLoading: Bool
    var dateRange: String = ""

    var body: some View {
        BriefingCardView(
            badge: "This week",
            dateRange: dateRange,
            headline: headline,
            accent: .exercise,
            isLoading: isLoading
        )
    }
}
