import SwiftUI

struct ExerciseBriefingView: View {
    let headline: String
    let summary: String
    let isLoading: Bool
    var dateRange: String = ""

    var body: some View {
        BriefingCardView(
            badge: "This week",
            dateRange: dateRange,
            headline: headline,
            summary: summary,
            accent: .exercise,
            isLoading: isLoading
        )
    }
}
