import SwiftUI
import SwiftData

struct WorkoutBuilderView: View {
    let type: WorkoutType?
    let template: WorkoutTemplate?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService
    @Environment(ThemeManager.self) private var theme

    @State private var viewModel: WorkoutBuilderViewModel?
    @State private var showRestEditor = false
    @State private var oneRMExerciseName: String?
    @State private var startWeightText = ""
    @State private var isEditingExercises = false
    @State private var showStartWorkoutConfirm = false
    @FocusState private var nameFocused: Bool

    init(type: WorkoutType?, template: WorkoutTemplate?) {
        self.type = type
        self.template = template
    }

    var body: some View {
        Group {
            if let viewModel {
                builderContent(viewModel)
            } else {
                ProgressView()
                    .tint(theme.colors.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.cardBackground.ignoresSafeArea())
            }
        }
        .fullScreenWidthBounds()
        .onAppear {
            guard viewModel == nil, let userId = appState.authenticatedUserId else { return }
            let vm = WorkoutBuilderViewModel(
                userId: userId,
                type: type,
                template: template
            )
            viewModel = vm
            vm.onAppear(context: modelContext)
        }
        .onDisappear {
            viewModel?.onDisappear()
        }
        .alert("Start workout?", isPresented: $showStartWorkoutConfirm) {
            Button("Start") {
                viewModel?.startActiveSession(context: modelContext)
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Your session timer will begin once you start.")
        }
    }

    @ViewBuilder
    private func builderContent(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel

        ZStack(alignment: .bottomTrailing) {
            theme.colors.cardBackground
                .ignoresSafeArea()

            Group {
                if viewModel.screenPhase == .setup {
                    setupPhase(viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    activePhase(viewModel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: viewModel.screenPhase)

            if viewModel.screenPhase == .active, viewModel.allCurrentSetsDone, viewModel.hasNextIncompleteExercise {
                Button {
                    viewModel.jumpToNextExercise()
                } label: {
                    HStack(spacing: 6) {
                        Text("NEXT EXERCISE")
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(theme.colors.textOnBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(theme.colors.accentGreen))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $viewModel.showExercisePicker) {
            ExercisePickerSheet(
                workoutType: viewModel.workoutType,
                onSelectCatalog: { viewModel.addExercise(from: $0) },
                onSelectCardio: { viewModel.addCardioOption($0) },
                onAddCustom: { viewModel.addCustomExercise(name: $0) }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $viewModel.editingExercise) { exercise in
            ExerciseDetailEditor(exercise: exercise) { updated in
                viewModel.updateExercise(updated)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestEditor) {
            RestDurationEditorSheet(seconds: viewModel.restDuration) { seconds in
                viewModel.updateRestDuration(seconds)
            }
        }
        .sheet(isPresented: Binding(
            get: { oneRMExerciseName != nil },
            set: { if !$0 { oneRMExerciseName = nil } }
        )) {
            if let name = oneRMExerciseName {
                OneRMDetailSheet(
                    exerciseName: name,
                    history: WorkoutAnalytics.oneRMHistory(
                        exerciseName: name,
                        userId: viewModel.userId,
                        context: modelContext
                    )
                )
            }
        }
        .confirmationDialog("End workout?", isPresented: $viewModel.showEndConfirm, titleVisibility: .visible) {
            Button("End Workout", role: .destructive) {
                viewModel.endWorkout(context: modelContext, syncService: syncService)
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $viewModel.showCompletion) {
            if let payload = viewModel.completionPayload {
                WorkoutCompleteView(payload: payload, template: viewModel.template) { result in
                    viewModel.finalizeWorkout(
                        context: modelContext,
                        syncService: syncService,
                        result: result
                    )
                    viewModel.showCompletion = false
                    dismiss()
                }
                .environment(theme)
            }
        }
    }

    // MARK: - Phase A: Setup

    @ViewBuilder
    private func setupPhase(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameCard(viewModel)
                    if viewModel.showTypeSelector {
                        typeSelector(viewModel)
                    }
                    dateTimeRow(viewModel)
                    exerciseList(viewModel)
                    addExerciseButton { viewModel.showExercisePicker = true }
                    notesCard(viewModel)
                    saveTemplateButton(viewModel)
                    startWorkoutButton(viewModel)
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .toolbarBackground(theme.colors.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func nameCard(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel
        return TextField("Workout name e.g. Push Day A", text: $viewModel.workoutName)
            .focused($nameFocused)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(theme.colors.textPrimary)
            .padding(14)
            .background(cardBackground)
            .onAppear { nameFocused = template == nil }
            .onChange(of: viewModel.workoutName) { _, _ in viewModel.limitWorkoutName() }
    }

    private func typeSelector(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutType.allCases) { workoutType in
                    let selected = viewModel.workoutType == workoutType
                    Button {
                        viewModel.workoutType = workoutType
                    } label: {
                        WorkoutTypeBadge(type: workoutType)
                            .overlay(
                                Capsule()
                                    .stroke(selected ? theme.colors.accentGreen : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dateTimeRow(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel
        return HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(theme.colors.accentGreen)
                DatePicker("", selection: $viewModel.scheduledDate, displayedComponents: .date)
                    .labelsHidden()
            }
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundStyle(theme.colors.accentGreen)
                DatePicker("", selection: $viewModel.scheduledDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(theme.colors.textPrimary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func exerciseList(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exercises")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                if viewModel.selectedExerciseIds.count >= 2 {
                    Button("Group as superset") {
                        viewModel.groupSelectedExercisesAsSuperset()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.accentGreen)
                }
                EditButton()
                    .foregroundStyle(theme.colors.accentGreen)
            }

            if viewModel.exercises.isEmpty {
                Text("Add at least one exercise")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                        VStack(spacing: 4) {
                            if index > 0 {
                                let prev = viewModel.exercises[index - 1]
                                if let group = exercise.supersetGroupId, prev.supersetGroupId == group {
                                    SupersetLinkIndicator()
                                }
                            }
                            HStack(spacing: 8) {
                                Button {
                                    viewModel.toggleExerciseSelection(exercise.id)
                                } label: {
                                    Image(systemName: viewModel.selectedExerciseIds.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.selectedExerciseIds.contains(exercise.id) ? theme.colors.accentGreen : theme.colors.textTertiary)
                                }
                                .buttonStyle(.plain)
                                ExerciseRowBuilder(exercise: exercise) {
                                    viewModel.editingExercise = exercise
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { viewModel.deleteExercise(at: $0) }
                    .onMove { viewModel.moveExercise(from: $0, to: $1) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(viewModel.exercises.count) * 88)
            }
        }
    }

    private func addExerciseButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("+ Add Exercise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.colors.accentGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.colors.accentGreen, style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .background(RoundedRectangle(cornerRadius: 12).fill(theme.colors.chipBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func notesCard(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel
        return TextField("Session notes (optional)", text: $viewModel.sessionNotes, axis: .vertical)
            .lineLimit(3...6)
            .font(.system(size: 15))
            .foregroundStyle(theme.colors.textPrimary)
            .padding(14)
            .background(cardBackground)
    }

    private func saveTemplateButton(_ viewModel: WorkoutBuilderViewModel) -> some View {
        Button {
            if viewModel.saveAsTemplate(context: modelContext, syncService: syncService) {
                dismiss()
            }
        } label: {
            Text("Save as template")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.colors.accentGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.colors.accentGreen, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canStartSetup)
    }

    private func startWorkoutButton(_ viewModel: WorkoutBuilderViewModel) -> some View {
        Button {
            showStartWorkoutConfirm = true
        } label: {
            Text("Start Workout")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.colors.textOnBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(viewModel.canStartSetup ? theme.colors.accentGreen : theme.colors.textTertiary)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canStartSetup)
    }

    // MARK: - Phase B: Active

    @ViewBuilder
    private func activePhase(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            activeHeader(viewModel)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseTab(viewModel: viewModel, index: index, exercise: exercise)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(theme.colors.chipBackground)

            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if viewModel.showWeightLogPrompt {
                            WorkoutStartWeightPrompt(
                                weightText: $startWeightText,
                                onSave: {
                                    if let weight = Double(startWeightText) {
                                        viewModel.logStartWeight(weight, context: modelContext)
                                        syncService.schedulePush(
                                            modelContext: modelContext,
                                            userId: appState.authenticatedUserId
                                        )
                                    }
                                },
                                onDismiss: { viewModel.dismissWeightLogPrompt() }
                            )
                        }
                        if let exercise = viewModel.currentExercise {
                            currentExerciseCard(viewModel, exercise: exercise)
                        }
                        if viewModel.showRestTimer {
                            BuilderRestTimerBar(
                                countdown: viewModel.restCountdownString,
                                progress: viewModel.restProgress,
                                isWarning: viewModel.restSecondsRemaining <= 10,
                                onSkip: { viewModel.skipRest() },
                                onEdit: { showRestEditor = true }
                            )
                        }
                        sessionNotesField(viewModel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .padding(.bottom, 80)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let toast = viewModel.prToast {
                    WorkoutPRToastBanner(toast: toast)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .zIndex(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: viewModel.prToast?.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func activeHeader(_ viewModel: WorkoutBuilderViewModel) -> some View {
        HStack(spacing: HabfitiseSpacing.md) {
            Text(viewModel.elapsedTimerString)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.colors.accentGreen)
                .monospacedDigit()
                .frame(minWidth: 64, alignment: .leading)

            Spacer(minLength: 8)

            Text(viewModel.trimmedName.isEmpty ? "Workout" : viewModel.trimmedName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button("End") {
                viewModel.showEndConfirm = true
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.colors.danger)
            .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, HabfitiseSpacing.xl)
        .padding(.vertical, 12)
        .safeAreaPadding(.horizontal, HabfitiseSpacing.sm)
        .background(theme.colors.chipBackground)
    }

    private func exerciseTab(viewModel: WorkoutBuilderViewModel, index: Int, exercise: BuilderDraftExercise) -> some View {
        let isCurrent = viewModel.currentExerciseIndex == index
        let sets = viewModel.setStates[exercise.id] ?? []
        let isDone = !sets.isEmpty && sets.allSatisfy(\.isCompleted)

        return Button {
            viewModel.selectExercise(at: index)
        } label: {
            HStack(spacing: 4) {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(exercise.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isCurrent ? theme.colors.textOnBackground : theme.colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isCurrent ? theme.colors.accentGreen :
                        isDone ? theme.colors.trackBackground :
                        Color.clear
                )
            )
            .overlay(
                Capsule().stroke(isCurrent || isDone ? Color.clear : theme.colors.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func currentExerciseCard(_ viewModel: WorkoutBuilderViewModel, exercise: BuilderDraftExercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary)
                HStack(spacing: 8) {
                    Text(exercise.category.rawValue.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.colors.accentGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.colors.chipDone))
                    Text("Exercise \(viewModel.currentExerciseIndex + 1) of \(viewModel.exercises.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }

            if exercise.type == .cardio, viewModel.cardioTimerExerciseId == exercise.id {
                CardioLiveTimerView(
                    seconds: viewModel.cardioTimerSeconds,
                    isRunning: viewModel.cardioTimerRunning,
                    onToggle: { viewModel.toggleCardioTimer() },
                    onStop: {
                        viewModel.stopCardioTimer(exerciseId: exercise.id)
                        if let set = viewModel.currentSets.first(where: { !$0.isCompleted }) {
                            viewModel.completeSet(setId: set.id, exerciseId: exercise.id, context: modelContext)
                        }
                    }
                )
            } else {
                setTableHeader(exercise: exercise)
                ForEach(Array(viewModel.currentSets.enumerated()), id: \.element.id) { index, set in
                    BuilderSetRow(
                        exercise: exercise,
                        set: set,
                        isFlashing: viewModel.flashSetId == set.id,
                        isFirstSet: index == 0,
                        volumeHint: viewModel.volumeProgressHints[exercise.id],
                        oneRMEstimate: viewModel.exerciseOneRMEstimates[exercise.id],
                        onOneRMInfo: { oneRMExerciseName = exercise.name },
                        onAdjustReps: { viewModel.adjustReps(setId: set.id, exerciseId: exercise.id, delta: $0) },
                        onAdjustWeight: { viewModel.adjustWeight(setId: set.id, exerciseId: exercise.id, delta: $0) },
                        onAdjustDuration: { viewModel.adjustDuration(setId: set.id, exerciseId: exercise.id, delta: $0) },
                        onAdjustDistance: { viewModel.adjustDistance(setId: set.id, exerciseId: exercise.id, delta: $0) },
                        onComplete: { viewModel.completeSet(setId: set.id, exerciseId: exercise.id, context: modelContext) },
                        onLongPress: { viewModel.toggleWarmup(setId: set.id, exerciseId: exercise.id) }
                    )
                }

                if exercise.type == .cardio {
                    Button("Use timer") {
                        viewModel.startCardioTimer(for: exercise.id)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.accentGreen)
                }

                Button {
                    viewModel.addSet(to: exercise.id)
                } label: {
                    Text("+ Add set")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if exercise.type == .cardio || exercise.type == .timed {
                    let first = viewModel.currentSets.first
                    Text("Pace: \(viewModel.paceLabel(duration: first?.durationSeconds, distance: first?.distanceKm))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.colors.fieldBackground)
        )
    }

    private func setTableHeader(exercise: BuilderDraftExercise) -> some View {
        HStack {
            Text("SET").frame(width: 28, alignment: .leading)
            Text("PREV").frame(width: 56, alignment: .leading)
            if exercise.type == .cardio || exercise.type == .timed {
                Text("TIME").frame(maxWidth: .infinity)
                Text("DIST").frame(maxWidth: .infinity)
            } else {
                Text("REPS").frame(maxWidth: .infinity)
                Text("WEIGHT").frame(maxWidth: .infinity)
            }
            Color.clear.frame(width: 28, height: 1)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(theme.colors.textTertiary)
    }

    private func sessionNotesField(_ viewModel: WorkoutBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel
        return TextField("Session notes...", text: $viewModel.sessionNotes, axis: .vertical)
            .lineLimit(2...4)
            .font(.system(size: 14))
            .foregroundStyle(theme.colors.textPrimary)
            .padding(12)
            .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(theme.colors.fieldBackground)
    }
}

#if DEBUG
struct WorkoutBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutBuilderView(type: .weights, template: nil)
            .environment(AppState())
            .environment(SyncService())
            .environment(ThemeManager())
            .modelContainer(try! SwiftDataStack.makeContainer(inMemory: true))
    }
}
#endif
