import SwiftUI

struct ShoppingTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "cart")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Shopping Lists")
                    .font(.title2.bold())
                Text("Coming in Phase 2")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Shopping")
        }
    }
}
