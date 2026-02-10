import SwiftUI

struct NotesTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Notes")
                    .font(.title2.bold())
                Text("Coming in Phase 2")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Notes")
        }
    }
}
