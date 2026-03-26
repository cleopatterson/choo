import SwiftUI

struct ExerciseTabView: View {
    @Bindable var viewModel: ExerciseViewModel
    @Binding var showingProfile: Bool

    @State private var hasPersona = ExercisePersona.current != nil

    var body: some View {
        if !hasPersona {
            ExerciseOnboardingView { _ in
                hasPersona = true
                // Trigger exercise auto-plan now that persona is set
                Task {
                    let manager = WeekPlanManager.shared
                    guard manager.shouldAutoPlanExercise() else { return }
                    guard manager.isExercisePlanEmpty(viewModel.firestoreService.currentExercisePlan) else { return }
                    guard !viewModel.firestoreService.exerciseCategories.isEmpty else { return }
                    print("[AutoPlan:Exercise] Post-onboarding trigger")
                    manager.exerciseState = .planning
                    do {
                        try await viewModel.autoPlanWeek()
                        manager.exerciseState = .done
                        manager.markExerciseAutoPlanDone()
                        print("[AutoPlan:Exercise] Post-onboarding success")
                    } catch {
                        print("[AutoPlan:Exercise] Post-onboarding failed: \(error)")
                        manager.exerciseState = .failed(error.localizedDescription)
                        manager.markExerciseAutoPlanDone()
                    }
                }
            }
        } else {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        ExerciseBriefingView(
                            headline: viewModel.briefingHeadline,
                            summary: viewModel.briefingSummary,
                            isLoading: viewModel.isLoadingBriefing,
                            dateRange: viewModel.weekDateRange
                        )

                        ExerciseHeroView(viewModel: viewModel)

                        ExerciseWeekStripView(viewModel: viewModel)

                        if viewModel.sessionCount > 0 || viewModel.healthKitService.weekAverageSteps > 0 || viewModel.healthKitService.weekExerciseMinutes > 0 {
                            ExerciseStatsBar(
                                plannedMinutes: viewModel.weekPlannedMinutes,
                                actualMinutes: viewModel.healthKitService.weekExerciseMinutes,
                                averageSteps: viewModel.healthKitService.weekAverageSteps,
                                totalCalories: viewModel.healthKitService.weekTotalCalories
                            )
                        }

                        ExerciseCategoriesView(viewModel: viewModel, scrollProxy: scrollProxy)
                    }
                    .padding()
                }
            }
            .chooBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .opacity(0.6)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Exercise")
                        .font(.system(.headline, design: .serif))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showingCategoryForm = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(item: Binding(
                get: { viewModel.selectedDayIndex.map { SheetIdentifier(id: $0) } },
                set: { viewModel.selectedDayIndex = $0?.id }
            )) { _ in
                ExerciseDayPlanSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $viewModel.showingCategoryForm) {
                ExerciseManageSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
        }
        } // else hasPersona
    }
}

private struct SheetIdentifier: Identifiable {
    let id: Int
}
