import SwiftUI

struct CalendarTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "calendar")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Calendar")
                    .font(.title2.bold())
                Text("Coming in Phase 2")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Calendar")
        }
    }
}
