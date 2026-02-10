import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        TabView {
            CalendarTabView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            ShoppingTabView()
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }

            NotesTabView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }

            AccountTabView(viewModel: viewModel)
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
        }
        .tint(.wallboardBlue)
    }
}
