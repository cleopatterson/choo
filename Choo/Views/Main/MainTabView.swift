import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AuthViewModel
    @Bindable var shoppingViewModel: ShoppingViewModel
    @Bindable var calendarViewModel: CalendarViewModel
    @Bindable var notesViewModel: NotesViewModel
    @Bindable var bugReportsViewModel: BugReportsViewModel
    @Bindable var briefingViewModel: WeeklyBriefingViewModel
    @Bindable var dinnerPlannerViewModel: DinnerPlannerViewModel
    @Bindable var exerciseViewModel: ExerciseViewModel
    @Bindable var houseViewModel: HouseViewModel
    @Bindable var suppliesViewModel: SuppliesViewModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showingProfile = false
    @State private var hasTriggeredAutoPlan = false

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarTabView(viewModel: calendarViewModel, briefingViewModel: briefingViewModel, showingProfile: $showingProfile)
                .tag(0)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            ShoppingTabView(viewModel: shoppingViewModel, dinnerPlannerViewModel: dinnerPlannerViewModel, suppliesViewModel: suppliesViewModel, showingProfile: $showingProfile)
                .tag(1)
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }

            ExerciseTabView(viewModel: exerciseViewModel, showingProfile: $showingProfile)
                .tag(2)
                .tabItem {
                    Label("Exercise", systemImage: "figure.run")
                }

            HouseTabView(viewModel: houseViewModel, showingProfile: $showingProfile)
                .tag(3)
                .tabItem {
                    Label("House", systemImage: "checklist")
                }

            NotesTabView(viewModel: notesViewModel, bugReportsViewModel: bugReportsViewModel, showingProfile: $showingProfile)
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
        .onAppear {
            if let date = NavigationRouter.shared.consumePendingNavigation() {
                selectedTab = 0
                calendarViewModel.selectedDate = Calendar.current.startOfDay(for: date)
            }
        }
        .onChange(of: NavigationRouter.shared.pendingEventDate) {
            if let date = NavigationRouter.shared.consumePendingNavigation() {
                selectedTab = 0
                calendarViewModel.selectedDate = Calendar.current.startOfDay(for: date)
            }
        }
        .task {
            await waitForDataThenAutoPlan()
        }
    }

    // MARK: - Auto-Plan

    private func waitForDataThenAutoPlan() async {
        guard !hasTriggeredAutoPlan else { return }
        hasTriggeredAutoPlan = true

        let manager = WeekPlanManager.shared
        manager.applyOneTimeResetIfNeeded()
        guard manager.anyTabNeedsAutoPlan() else {
            print("[AutoPlan] No tabs need auto-planning this week")
            return
        }

        print("[AutoPlan] Starting — loading VMs")

        // Ensure all three VMs have started their Firestore listeners.
        await dinnerPlannerViewModel.load()
        await exerciseViewModel.load()
        await houseViewModel.load()

        // Wait for Firestore listeners to deliver data
        let firestore = dinnerPlannerViewModel.firestoreService
        for i in 0..<20 {
            let hasRecipes = !firestore.recipes.isEmpty
            let hasChoreCategories = !firestore.choreCategories.isEmpty
            if hasRecipes && hasChoreCategories { break }
            if i > 0 { print("[AutoPlan] Waiting for data... poll \(i)") }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        print("[AutoPlan] Data ready. Recipes=\(firestore.recipes.count), ExCats=\(firestore.exerciseCategories.count), ChoreCats=\(firestore.choreCategories.count)")

        // Fire all three concurrently — each has its own per-tab guard
        async let dinnerResult: () = autoPlanDinners(manager: manager)
        async let exerciseResult: () = autoPlanExercise(manager: manager)
        async let choresResult: () = autoPlanChores(manager: manager)

        _ = await (dinnerResult, exerciseResult, choresResult)
        print("[AutoPlan] Done")
    }

    private func autoPlanDinners(manager: WeekPlanManager) async {
        guard manager.shouldAutoPlanDinners() else { return }
        guard manager.isMealPlanEmpty(dinnerPlannerViewModel.firestoreService.currentMealPlan) else {
            print("[AutoPlan:Dinner] Skipped — plan not empty")
            manager.markDinnerAutoPlanDone()
            return
        }
        guard !dinnerPlannerViewModel.firestoreService.recipes.isEmpty else {
            print("[AutoPlan:Dinner] Skipped — no recipes")
            return
        }
        print("[AutoPlan:Dinner] Planning...")
        manager.dinnerState = .planning
        do {
            try await dinnerPlannerViewModel.autoPlanWeek()
            print("[AutoPlan:Dinner] Success")
            manager.dinnerState = .done
            manager.markDinnerAutoPlanDone()
        } catch {
            print("[AutoPlan:Dinner] Failed: \(error)")
            manager.dinnerState = .failed(error.localizedDescription)
            manager.markDinnerAutoPlanDone()  // Don't retry — brief says no retries
        }
    }

    private func autoPlanExercise(manager: WeekPlanManager) async {
        guard manager.shouldAutoPlanExercise() else { return }
        guard manager.isExercisePlanEmpty(exerciseViewModel.firestoreService.currentExercisePlan) else {
            print("[AutoPlan:Exercise] Skipped — plan not empty")
            manager.markExerciseAutoPlanDone()
            return
        }
        guard !exerciseViewModel.firestoreService.exerciseCategories.isEmpty else {
            print("[AutoPlan:Exercise] Skipped — no categories")
            return
        }
        guard ExercisePersona.current != nil else {
            print("[AutoPlan:Exercise] Skipped — no persona set yet")
            return  // Don't stamp — will retry after user completes onboarding
        }
        print("[AutoPlan:Exercise] Planning... persona=\(ExercisePersona.current!.rawValue)")
        manager.exerciseState = .planning
        do {
            try await exerciseViewModel.autoPlanWeek()
            print("[AutoPlan:Exercise] Success")
            manager.exerciseState = .done
            manager.markExerciseAutoPlanDone()
        } catch {
            print("[AutoPlan:Exercise] Failed: \(error)")
            manager.exerciseState = .failed(error.localizedDescription)
            manager.markExerciseAutoPlanDone()
        }
    }

    private func autoPlanChores(manager: WeekPlanManager) async {
        guard manager.shouldAutoPlanChores() else { return }
        guard manager.isChoresPlanEmpty(dayPlan: houseViewModel.firestoreService.choreDayPlan) else {
            print("[AutoPlan:Chores] Skipped — plan not empty")
            manager.markChoresAutoPlanDone()
            return
        }
        guard !houseViewModel.firestoreService.choreCategories.isEmpty else {
            print("[AutoPlan:Chores] Skipped — no categories")
            return
        }
        print("[AutoPlan:Chores] Planning...")
        manager.choresState = .planning
        do {
            try await houseViewModel.autoPlanWeek()
            print("[AutoPlan:Chores] Success")
            manager.choresState = .done
            manager.markChoresAutoPlanDone()
        } catch {
            print("[AutoPlan:Chores] Failed: \(error)")
            manager.choresState = .failed(error.localizedDescription)
            manager.markChoresAutoPlanDone()
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
