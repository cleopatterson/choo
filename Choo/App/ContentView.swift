import SwiftUI

struct ContentView: View {
    @State var viewModel: AuthViewModel
    @State private var shoppingViewModel: ShoppingViewModel?
    @State private var calendarViewModel: CalendarViewModel?
    @State private var notesViewModel: NotesViewModel?
    @State private var bugReportsViewModel: BugReportsViewModel?
    @State private var dinnerPlannerViewModel: DinnerPlannerViewModel?
    @State private var exerciseViewModel: ExerciseViewModel?
    @State private var houseViewModel: HouseViewModel?
    @State private var deviceCalendarService = DeviceCalendarService()

    var body: some View {
        Group {
            switch viewModel.authFlowState {
            case .loading:
                LoadingView()
            case .login:
                LoginView(viewModel: viewModel)
            case .signUp:
                SignUpView(viewModel: viewModel)
            case .familySetup:
                FamilySetupView(viewModel: viewModel)
            case .ready:
                if let shoppingVM = shoppingViewModel,
                   let calendarVM = calendarViewModel,
                   let notesVM = notesViewModel,
                   let bugReportsVM = bugReportsViewModel,
                   let dinnerVM = dinnerPlannerViewModel,
                   let exerciseVM = exerciseViewModel,
                   let houseVM = houseViewModel {
                    MainTabView(
                        viewModel: viewModel,
                        shoppingViewModel: shoppingVM,
                        calendarViewModel: calendarVM,
                        notesViewModel: notesVM,
                        bugReportsViewModel: bugReportsVM,
                        dinnerPlannerViewModel: dinnerVM,
                        exerciseViewModel: exerciseVM,
                        houseViewModel: houseVM
                    )
                } else {
                    LoadingView()
                }
            }
        }
        .animation(.default, value: viewModel.authFlowState)
        .task { await viewModel.resolveAuthState() }
        .onChange(of: viewModel.authService.currentUser?.uid) {
            Task { await viewModel.resolveAuthState() }
        }
        // Auth restore finishing with no user changes only isLoading (uid stays
        // nil→nil), so watch it too or a cached session strands on a dead UI.
        .onChange(of: viewModel.authService.isLoading) {
            Task { await viewModel.resolveAuthState() }
        }
        .onChange(of: viewModel.authFlowState) {
            if viewModel.authFlowState == .ready,
               let familyId = viewModel.userProfile?.familyId {
                let displayName = viewModel.userProfile?.displayName ?? "Unknown"
                let firestore = viewModel.firestoreService

                shoppingViewModel = ShoppingViewModel(
                    firestoreService: firestore,
                    familyId: familyId,
                    displayName: displayName
                )
                let uid = viewModel.authService.currentUser?.uid ?? ""
                calendarViewModel = CalendarViewModel(
                    firestoreService: firestore,
                    deviceCalendarService: deviceCalendarService,
                    familyId: familyId,
                    displayName: displayName,
                    currentUserUID: uid
                )
                notesViewModel = NotesViewModel(
                    firestoreService: firestore,
                    familyId: familyId,
                    displayName: displayName
                )
                bugReportsViewModel = BugReportsViewModel(
                    firestoreService: firestore,
                    familyId: familyId,
                    displayName: displayName
                )
                dinnerPlannerViewModel = DinnerPlannerViewModel(
                    firestoreService: firestore,
                    familyId: familyId,
                    displayName: displayName,
                    userUID: uid
                )
                exerciseViewModel = ExerciseViewModel(
                    firestoreService: firestore,
                    claudeService: .shared,
                    familyId: familyId,
                    userId: uid,
                    displayName: displayName
                )
                houseViewModel = HouseViewModel(
                    firestoreService: firestore,
                    claudeService: .shared,
                    familyId: familyId,
                    displayName: displayName
                )
                SharedUserContext.save(
                    uid: uid,
                    familyId: familyId,
                    displayName: displayName
                )
                PushNotificationService.shared.saveFCMToken(uid: uid)
            } else if viewModel.authFlowState != .ready {
                shoppingViewModel = nil
                calendarViewModel = nil
                notesViewModel = nil
                bugReportsViewModel = nil
                dinnerPlannerViewModel = nil
                exerciseViewModel = nil
                houseViewModel = nil
                SharedUserContext.clear()
            }
        }
    }
}
