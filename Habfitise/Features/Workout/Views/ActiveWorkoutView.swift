import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService

    @Bindable var viewModel: ActiveWorkoutViewModel

    @State private var showExerciseList = false
    @State private var barGlowActive = false

    var body: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: HabfitiseSpacing.lg) {
                    headerRow
                    progressBar
                    Text(viewModel.exerciseProgressLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity)

                    ExerciseBarChart(
                        exercises: viewModel.chartExercises,
                        currentIndex: viewModel.currentExerciseIndex,
                        glowCurrentBar: barGlowActive
                    )

                    HStack {
                        Text("\(viewModel.sessionExercises.count) exercises")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.colors.accentGreen)
                        Spacer()
                        Text("\(viewModel.completionPercent)%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.colors.accentGreen)
                    }

                    currentExerciseCard

                    Button {
                        showExerciseList = true
                    } label: {
                        HStack {
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 36, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, HabfitiseSpacing.lg)
                .padding(.top, HabfitiseSpacing.sm)
                .padding(.bottom, HabfitiseSpacing.xxxl)
            }

            if viewModel.showRestTimer {
                RestTimerOverlay(
                    countdown: viewModel.restCountdownString,
                    progress: viewModel.restProgress,
                    onSkip: viewModel.skipRest
                )
            }
        }
        .onAppear {
            viewModel.onAppear(context: modelContext)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $showExerciseList) {
            ExerciseListSheet(
                exercises: viewModel.sessionExercises,
                currentIndex: viewModel.currentExerciseIndex
            ) { index in
                viewModel.jumpToExercise(at: index)
                showExerciseList = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.colors.background)
        }
        .fullScreenCover(isPresented: $viewModel.showCompletionSheet) {
            if let stats = viewModel.completionStats {
                WorkoutCompleteView(stats: stats, workoutName: viewModel.workoutName) {
                    viewModel.showCompletionSheet = false
                    dismiss()
                }
                .environment(theme)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textOnBackground)
            }

            Spacer()

            Text(viewModel.workoutName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Button("End") {
                viewModel.endWorkout(context: modelContext, syncService: syncService)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.colors.danger)
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.colors.chipBackground)
                    .frame(height: 4)

                Capsule()
                    .fill(theme.colors.accentGreen)
                    .frame(width: geometry.size.width * viewModel.currentProgress, height: 4)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.currentProgress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Exercise Card

    private var currentExerciseCard: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            Text(viewModel.exerciseName)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary)

            Text("Set \(viewModel.currentSetIndex) of \(viewModel.totalSetsForCurrentExercise) · Today")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(theme.colors.textSecondary)

            statsSection

            Text(viewModel.lastTimeSummary)
                .font(.system(size: 13, weight: .regular))
                .italic()
                .foregroundStyle(theme.colors.textSecondary)
                .padding(.top, 8)

            WorkoutDoneButton(title: "Done — Start rest timer") {
                handleDoneTap()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
        .padding(.top, HabfitiseSpacing.lg)
    }

    private var statsSection: some View {
        VStack(spacing: HabfitiseSpacing.md) {
            if viewModel.editingField == .reps {
                WorkoutInlineStepper(
                    valueText: "\(viewModel.currentReps)",
                    onDecrement: viewModel.decrementReps,
                    onIncrement: viewModel.incrementReps
                )
            } else if viewModel.editingField == .weight {
                WorkoutInlineStepper(
                    valueText: String(format: "%.1f", viewModel.currentWeightKg),
                    onDecrement: viewModel.decrementWeight,
                    onIncrement: viewModel.incrementWeight
                )
            }

            HStack(spacing: 0) {
                WorkoutStatColumn(
                    value: "\(viewModel.currentReps)",
                    label: "Reps",
                    onTap: { viewModel.toggleEditing(.reps) }
                )

                WorkoutStatColumn(
                    value: String(format: "%.1f kg", viewModel.currentWeightKg),
                    label: "Weight",
                    onTap: { viewModel.toggleEditing(.weight) }
                )

                WorkoutStatColumn(
                    value: viewModel.timerString,
                    label: "Rest",
                    valueColor: viewModel.showRestTimer ? theme.colors.accentGreen : theme.colors.textPrimary,
                    onTap: {}
                )
            }
        }
    }

    private func handleDoneTap() {
        guard case .active = viewModel.phase else { return }

        viewModel.completeCurrentSet(context: modelContext, syncService: syncService)

        guard case .complete = viewModel.phase else {
            pulseBarGlow()
            return
        }
    }

    private func pulseBarGlow() {
        barGlowActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            barGlowActive = false
        }
    }
}

#if DEBUG
struct ActiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveWorkoutView(
            viewModel: ActiveWorkoutViewModel(
                userId: "preview",
                workoutName: "Upper Body Push",
                exercises: ActiveWorkoutFactory.defaultExercises(for: "Upper Body Push")
            )
        )
        .environment(AppState())
        .environment(SyncService())
            .environment(ThemeManager())
    }
}
#endif
