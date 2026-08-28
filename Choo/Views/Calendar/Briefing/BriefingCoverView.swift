import SwiftUI

struct BriefingCoverView: View {
    let headline: String
    let weekLabel: String
    var badge: String = "This week"
    var isNextWeek: Bool = false
    var isLoading: Bool = false

    var body: some View {
        BriefingCardView(
            badge: badge,
            dateRange: weekLabel,
            headline: headline,
            accent: .calendar,
            isLoading: isLoading
        )
    }
}
