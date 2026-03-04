import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AuthViewModel
    @Bindable var shoppingViewModel: ShoppingViewModel
    @Bindable var calendarViewModel: CalendarViewModel
    @Bindable var notesViewModel: NotesViewModel
    @Bindable var briefingViewModel: WeeklyBriefingViewModel
    @Bindable var dinnerPlannerViewModel: DinnerPlannerViewModel
    @Bindable var exerciseViewModel: ExerciseViewModel
    @Bindable var choresViewModel: ChoresViewModel

    @State private var selectedTab = 0
    @State private var showingProfile = false

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarTabView(viewModel: calendarViewModel, briefingViewModel: briefingViewModel, showingProfile: $showingProfile)
                .tag(0)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            ShoppingTabView(viewModel: shoppingViewModel, dinnerPlannerViewModel: dinnerPlannerViewModel, showingProfile: $showingProfile)
                .tag(1)
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }

            ExerciseTabView(viewModel: exerciseViewModel, showingProfile: $showingProfile)
                .tag(2)
                .tabItem {
                    Label("Exercise", systemImage: "figure.run")
                }

            ChoresTabView(viewModel: choresViewModel, showingProfile: $showingProfile)
                .tag(3)
                .tabItem {
                    Label("Chores", systemImage: "list.bullet.clipboard")
                }

            NotesTabView(viewModel: notesViewModel, showingProfile: $showingProfile)
                .tag(4)
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
        }
        .sheet(isPresented: $showingProfile) {
            AccountTabView(viewModel: viewModel)
        }
        .tint(.chooPurple)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .onAppear {
            rescheduleNotifications()
        }
        .onChange(of: eventsFingerprint) {
            rescheduleNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chooNavigateToDate)) { notification in
            if let date = notification.userInfo?["date"] as? Date {
                selectedTab = 0
                calendarViewModel.selectedDate = Calendar.current.startOfDay(for: date)
            }
        }
    }

    private var eventsFingerprint: Int {
        calendarViewModel.firestoreService.eventsVersion
    }

    private func rescheduleNotifications() {
        let events = calendarViewModel.firestoreService.events
        NotificationService.shared.rescheduleAll(events: events, currentUserUID: calendarViewModel.currentUserUID)
    }
}
