import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit

@Observable
@MainActor
final class WorkoutBuilderViewModel {
    enum ScreenPhase: Equatable {
        case setup
        case active
    }

    let userId: String
    let template: WorkoutTemplate?

    var workoutType: WorkoutType
    var workoutName: String
    var sessionNotes: String
    var scheduledDate: Date
    var exercises: [BuilderDraftExercise]
    var screenPhase: ScreenPhase = .setup
    var showTypeSelector: Bool

    var sessionId: UUID
    var startedAt: Date?
    var elapsedSeconds: Int = 0
    var currentExerciseIndex: Int = 0
    var setStates: [UUID: [BuilderSetState]] = [:]
    var exerciseNotes: [UUID: String] = [:]

    var showExercisePicker = false
    var editingExercise: BuilderDraftExercise?
    var showEndConfirm = false
    var showCompletion = false
    var completionPayload: WorkoutCompletePayload?
    private(set) var sessionPRs: [WorkoutCompletePR] = []

    var showRestTimer = false
    var restSecondsRemaining = 0
    var restDuration = 90
    private var recoveryContext = RecoveryContext.empty
    var flashSetId: UUID?
    var prToast: WorkoutPRToast?
    var editingSetField: SetField?
    var cardioTimerExerciseId: UUID?
    var cardioTimerRunning = false
    var cardioTimerSeconds = 0

    var selectedExerciseIds: Set<UUID> = []
    var volumeProgressHints: [UUID: VolumeProgressHint] = [:]
    var exerciseOneRMEstimates: [UUID: Double] = [:]
    var showWeightLogPrompt = false
    var profileBodyWeightKg: Double = 75

    private var elapsedTask: Task<Void, Never>?
    private var restTask: Task<Void, Never>?
    private var cardioTimerTask: Task<Void, Never>?

    enum SetField: Equatable {
        case reps(UUID)
        case weight(UUID)
        case duration(UUID)
        case distance(UUID)
    }

    init(
        userId: String,
        type: WorkoutType?,
        template: WorkoutTemplate?
    ) {
        self.userId = userId
        self.template = template
        self.workoutType = template?.type ?? type ?? .weights
        self.showTypeSelector = template == nil
        self.sessionId = UUID()

        if let template {
            workoutName = template.name
            sessionNotes = template.notes
            scheduledDate = template.nextScheduledAt ?? .now
            exercises = template.exercises
                .sorted { $0.order < $1.order }
                .map { BuilderDraftExercise(from: $0) }
        } else {
            workoutName = ""
            sessionNotes = ""
            scheduledDate = .now
            exercises = []
        }
    }

    var canStartSetup: Bool {
        !trimmedName.isEmpty && !exercises.isEmpty
    }

    var trimmedName: String {
        workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var elapsedTimerString: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var restCountdownString: String {
        let m = restSecondsRemaining / 60
        let s = restSecondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var restProgress: Double {
        guard restDuration > 0 else { return 0 }
        return Double(restSecondsRemaining) / Double(restDuration)
    }

    var currentExercise: BuilderDraftExercise? {
        exercises[safe: currentExerciseIndex]
    }

    var currentSets: [BuilderSetState] {
        guard let exercise = currentExercise else { return [] }
        return setStates[exercise.id] ?? []
    }

    var allCurrentSetsDone: Bool {
        let sets = currentSets
        return !sets.isEmpty && sets.allSatisfy(\.isCompleted)
    }

    var hasNextIncompleteExercise: Bool {
        exercises.indices.contains { index in
            guard index > currentExerciseIndex else { return false }
            let sets = setStates[exercises[index].id] ?? []
            return sets.isEmpty || !sets.allSatisfy(\.isCompleted)
        }
    }

    func onAppear(context: ModelContext) {
        _ = context
    }

    func onDisappear() {
        elapsedTask?.cancel()
        restTask?.cancel()
        cardioTimerTask?.cancel()
    }

    // MARK: - Setup

    func limitWorkoutName() {
        if workoutName.count > 40 {
            workoutName = String(workoutName.prefix(40))
        }
    }

    func addExercise(from catalog: CatalogExercise) {
        let draft = BuilderDraftExercise(
            name: catalog.name,
            category: catalog.category,
            type: catalog.type,
            defaultSets: catalog.type == .timed ? 1 : 3,
            defaultReps: catalog.type == .bodyweight ? 12 : 10,
            defaultWeightKg: catalog.type == .weighted ? 40 : 0,
            defaultDurationSeconds: catalog.type == .timed ? 60 : 0,
            restSeconds: defaultRest(for: catalog.type),
            order: exercises.count
        )
        exercises.append(draft)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func addCustomExercise(name: String, category: ExerciseCategory = .full) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let type: ExerciseType = workoutType == .cardio ? .cardio : (workoutType == .bodyweight ? .bodyweight : .weighted)
        exercises.append(
            BuilderDraftExercise(
                name: trimmed,
                category: category,
                type: type,
                defaultSets: workoutType == .cardio ? 1 : 3,
                restSeconds: defaultRest(for: type),
                order: exercises.count
            )
        )
    }

    func addCardioOption(_ option: CardioOption) {
        exercises.append(
            BuilderDraftExercise(
                name: option.name,
                category: .cardio,
                type: .cardio,
                defaultSets: 1,
                defaultDurationSeconds: 20 * 60,
                defaultDistanceKm: 3,
                restSeconds: 0,
                order: exercises.count
            )
        )
    }

    func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        reindexExercises()
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
        reindexExercises()
    }

    func updateExercise(_ exercise: BuilderDraftExercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[index] = exercise
    }

    @discardableResult
    func saveAsTemplate(context: ModelContext, syncService: SyncService) -> Bool {
        guard canStartSetup else { return false }
        reindexExercises()

        let savedTemplate: WorkoutTemplate
        if let template {
            updateLoadedTemplate(template, context: context)
            savedTemplate = template
        } else {
            savedTemplate = createTemplate(context: context)
        }

        do {
            try context.save()
        } catch {
            return false
        }

        refreshWorkoutReminder(for: savedTemplate)
        Task {
            await syncService.sync(
                modelContext: context,
                userId: userId,
                mode: .incremental,
                scope: .workout,
                force: true
            )
        }
        return true
    }

    func startActiveSession(context: ModelContext) {
        guard canStartSetup || template != nil else { return }
        screenPhase = .active
        startedAt = .now
        currentExerciseIndex = 0
        loadProfileWeight(context: context)
        initializeSetStates(context: context)
        loadVolumeProgressHints(context: context)
        showWeightLogPrompt = true
        startElapsedTimer()
        Task {
            await loadRecoveryContext(context: context)
            updateLiveActivity(restSeconds: nil)
        }
        WorkoutLiveActivityManager.start(
            workoutName: trimmedName.isEmpty ? "Workout" : trimmedName,
            exerciseName: exercises.first?.name ?? "Exercise",
            setLabel: "Set 1"
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {}
    }

    func loadRecoveryContext(context: ModelContext) async {
        await HealthKitService.shared.syncAuthorizationRequestStatus()
        let health = await HealthKitService.shared.fetchTodaySnapshot()
        let yesterday = ActivityEngine.yesterdaySessions(userId: userId, context: context)
        recoveryContext = ActivityEngine.recoveryContext(
            health: health,
            yesterdaySessions: yesterday
        )
    }

    func toggleExerciseSelection(_ exerciseId: UUID) {
        if selectedExerciseIds.contains(exerciseId) {
            selectedExerciseIds.remove(exerciseId)
        } else {
            selectedExerciseIds.insert(exerciseId)
        }
    }

    func groupSelectedExercisesAsSuperset() {
        guard selectedExerciseIds.count >= 2 else { return }
        let groupId = UUID()
        for index in exercises.indices where selectedExerciseIds.contains(exercises[index].id) {
            exercises[index].supersetGroupId = groupId
        }
        selectedExerciseIds.removeAll()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func logStartWeight(_ kg: Double, context: ModelContext) {
        guard kg > 0 else { return }
        let normalizedUserId = userId.lowercased()
        let entry = BodyWeightEntry(userId: normalizedUserId, weightKg: kg, synced: false)
        context.insert(entry)

        let userIdConst = normalizedUserId
        if let profile = try? context.fetch(FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userIdConst }
        )).first {
            profile.weightKg = kg
            profile.synced = false
            profile.updatedAt = .now
        }

        profileBodyWeightKg = kg
        try? context.save()
        showWeightLogPrompt = false
    }

    func dismissWeightLogPrompt() {
        showWeightLogPrompt = false
    }

    // MARK: - Active session

    func selectExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
        restTask?.cancel()
        showRestTimer = false
    }

    func jumpToNextExercise() {
        guard let next = exercises.indices.first(where: { index in
            index > currentExerciseIndex && !(setStates[exercises[index].id] ?? []).allSatisfy(\.isCompleted)
        }) else { return }
        selectExercise(at: next)
    }

    func addSet(to exerciseId: UUID) {
        guard let exercise = exercises.first(where: { $0.id == exerciseId }) else { return }
        var sets = setStates[exerciseId] ?? []
        let number = sets.count + 1
        sets.append(
            BuilderSetState(
                setNumber: number,
                reps: exercise.defaultReps,
                weightKg: exercise.type == .bodyweight ? 0 : exercise.defaultWeightKg,
                durationSeconds: exercise.defaultDurationSeconds > 0 ? exercise.defaultDurationSeconds : nil,
                distanceKm: exercise.defaultDistanceKm > 0 ? exercise.defaultDistanceKm : nil,
                previousSummary: sets.last?.previousSummary ?? "—"
            )
        )
        setStates[exerciseId] = sets
    }

    func toggleWarmup(setId: UUID, exerciseId: UUID) {
        guard var sets = setStates[exerciseId],
              let index = sets.firstIndex(where: { $0.id == setId }) else { return }
        sets[index].isWarmup.toggle()
        setStates[exerciseId] = sets
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func adjustReps(setId: UUID, exerciseId: UUID, delta: Int) {
        mutateSet(setId: setId, exerciseId: exerciseId) { $0.reps = max(0, ($0.reps ?? 0) + delta) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func adjustWeight(setId: UUID, exerciseId: UUID, delta: Double) {
        mutateSet(setId: setId, exerciseId: exerciseId) {
            let current = $0.weightKg ?? 0
            $0.weightKg = max(0, current + delta)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func adjustDuration(setId: UUID, exerciseId: UUID, delta: Int) {
        mutateSet(setId: setId, exerciseId: exerciseId) {
            let current = $0.durationSeconds ?? 0
            $0.durationSeconds = max(0, current + delta)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func adjustDistance(setId: UUID, exerciseId: UUID, delta: Double) {
        mutateSet(setId: setId, exerciseId: exerciseId) {
            let current = $0.distanceKm ?? 0
            $0.distanceKm = max(0, ((current + delta) * 10).rounded() / 10)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func completeSet(setId: UUID, exerciseId: UUID, context: ModelContext) {
        guard var sets = setStates[exerciseId],
              let index = sets.firstIndex(where: { $0.id == setId }),
              let exercise = exercises.first(where: { $0.id == exerciseId }) else { return }

        sets[index].isCompleted = true
        setStates[exerciseId] = sets

        let row = sets[index]
        let exerciseSet = ExerciseSet(
            sessionId: sessionId,
            userId: userId.lowercased(),
            exerciseName: exercise.name,
            exerciseCategory: exercise.category.rawValue,
            setNumber: row.setNumber,
            reps: row.reps,
            weightKg: exercise.type == .bodyweight ? nil : row.weightKg,
            durationSeconds: row.durationSeconds,
            distanceKm: row.distanceKm,
            isWarmup: row.isWarmup,
            completedAt: .now,
            synced: false
        )
        exerciseSet.markPendingSync()
        context.insert(exerciseSet)

        let previousWeight = SwiftDataStack.shared.fetchPR(
            userId: userId,
            exerciseName: exercise.name,
            type: .maxWeight
        )
        if let pr = SwiftDataStack.shared.checkForNewPR(set: exerciseSet, userId: userId) {
            context.insert(pr)
            sets[index].isPersonalRecord = true
            setStates[exerciseId] = sets
            let prDetail = formatPRValue(pr)
            recordSessionPR(
                exerciseName: exercise.name,
                newValue: prDetail,
                previousValue: previousWeight.map { formatPRValue($0) }
            )
            showPRToast(exerciseName: exercise.name, detail: prDetail)
        }

        if exercise.type == .weighted, let weight = row.weightKg, let reps = row.reps, reps > 0 {
            if let estimate = WorkoutAnalytics.storeEstimatedOneRMIfNeeded(
                exerciseName: exercise.name,
                weightKg: weight,
                reps: reps,
                sessionId: sessionId,
                userId: userId,
                context: context
            ) {
                exerciseOneRMEstimates[exerciseId] = estimate
            }
        }

        try? context.save()

        flashSetId = setId
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            flashSetId = nil
        }

        let rest = ActivityEngine.recommendedRestSeconds(
            base: exercise.restSeconds,
            context: recoveryContext,
            workoutType: workoutType
        )
        if shouldSkipRestAfterSuperset(completedExerciseId: exerciseId, completedSetNumber: row.setNumber) {
            if let partnerIndex = supersetPartnerIndex(for: exerciseId) {
                currentExerciseIndex = partnerIndex
            }
            return
        }

        if let partnerIndex = supersetPartnerIndex(for: exerciseId),
           let partner = exercises[safe: partnerIndex],
           let partnerSets = setStates[partner.id],
           partnerSets.contains(where: { !$0.isCompleted && $0.setNumber == row.setNumber }) {
            currentExerciseIndex = partnerIndex
            return
        }

        let allSetsDone = (setStates[exerciseId] ?? []).allSatisfy(\.isCompleted)
        if allSetsDone && hasNextIncompleteExercise {
            restTask?.cancel()
            showRestTimer = false
            return
        }

        guard rest > 0 else { return }
        startRest(seconds: rest)
    }

    func skipRest() {
        restTask?.cancel()
        showRestTimer = false
    }

    func updateRestDuration(_ seconds: Int) {
        restDuration = max(0, min(300, seconds))
        if showRestTimer { restSecondsRemaining = restDuration }
        if let exercise = currentExercise {
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                exercises[index].restSeconds = restDuration
            }
        }
    }

    func startCardioTimer(for exerciseId: UUID) {
        cardioTimerExerciseId = exerciseId
        cardioTimerSeconds = 0
        cardioTimerRunning = true
        runCardioTimerTickLoop()
    }

    func toggleCardioTimer() {
        guard cardioTimerExerciseId != nil else { return }
        cardioTimerRunning.toggle()
        if cardioTimerRunning {
            runCardioTimerTickLoop()
        } else {
            cardioTimerTask?.cancel()
        }
    }

    func stopCardioTimer(exerciseId: UUID) {
        cardioTimerTask?.cancel()
        cardioTimerRunning = false
        guard var sets = setStates[exerciseId], let firstIndex = sets.indices.first else { return }
        sets[firstIndex].durationSeconds = cardioTimerSeconds
        setStates[exerciseId] = sets
        cardioTimerExerciseId = nil
    }

    private func runCardioTimerTickLoop() {
        cardioTimerTask?.cancel()
        cardioTimerTask = Task {
            while !Task.isCancelled, cardioTimerRunning {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                cardioTimerSeconds += 1
            }
        }
    }

    func prepareEndWorkout() {
        elapsedTask?.cancel()
        restTask?.cancel()
        WorkoutLiveActivityManager.end()

        let completedSets = setStates.values.flatMap { $0 }.filter(\.isCompleted)
        let volume = completedSets.reduce(0.0) { partial, set in
            partial + (set.weightKg ?? 0) * Double(set.reps ?? 0)
        }

        completionPayload = WorkoutCompletePayload(
            workoutName: trimmedName.isEmpty ? "Workout" : trimmedName,
            workoutType: workoutType,
            durationSeconds: elapsedSeconds,
            totalVolumeKg: volume,
            totalSets: completedSets.count,
            sessionNotes: sessionNotes,
            newPRs: sessionPRs.dedupedByExercise(),
            estimatedCalories: WorkoutAnalytics.estimatedCalories(
                workoutType: workoutType,
                durationSeconds: elapsedSeconds,
                bodyWeightKg: profileBodyWeightKg
            )
        )
        showCompletion = true
    }

    func finalizeWorkout(
        context: ModelContext,
        syncService: SyncService,
        result: WorkoutCompleteResult
    ) {
        guard let payload = completionPayload else { return }

        sessionNotes = result.notes

        let session = WorkoutSession(
            id: sessionId,
            userId: userId.lowercased(),
            templateId: template?.id,
            name: payload.workoutName,
            type: workoutType,
            startedAt: startedAt ?? .now,
            completedAt: .now,
            durationSeconds: payload.durationSeconds,
            totalVolumeKg: payload.totalVolumeKg,
            totalCalories: payload.estimatedCalories,
            notes: result.notes,
            perceivedExertion: result.perceivedExertion,
            synced: false
        )
        context.insert(session)
        session.markPendingSync()

        if let template {
            template.lastPerformedAt = .now
            if result.scheduleRepeat {
                template.nextScheduledAt = repeatDate(for: result)
                template.repeatSchedule = result.repeatSchedule
            } else {
                applyScheduledDate(to: template)
            }
            template.markPendingSync()
        } else if result.scheduleRepeat {
            saveRepeatTemplate(context: context, result: result, payload: payload)
        }

        do {
            try context.save()
        } catch {
            return
        }

        if let template {
            refreshWorkoutReminder(for: template)
        } else if result.scheduleRepeat,
                  let newTemplate = fetchLatestTemplate(
                    userId: userId,
                    name: payload.workoutName,
                    context: context
                  ) {
            refreshWorkoutReminder(for: newTemplate)
        }

        syncService.schedulePush(modelContext: context, userId: userId.lowercased())

        Task {
            await HealthKitService.shared.saveWorkoutSession(session)
        }
    }

    private func fetchLatestTemplate(userId: String, name: String, context: ModelContext) -> WorkoutTemplate? {
        let userIdConst = userId
        let nameConst = name
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.userId == userIdConst && $0.name == nameConst },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    private func saveRepeatTemplate(
        context: ModelContext,
        result: WorkoutCompleteResult,
        payload: WorkoutCompletePayload
    ) {
        let newTemplate = WorkoutTemplate(
            userId: userId,
            name: payload.workoutName,
            type: workoutType,
            exercises: [],
            estimatedMinutes: max(payload.durationSeconds / 60, 30),
            lastPerformedAt: .now,
            nextScheduledAt: repeatDate(for: result),
            repeatSchedule: result.repeatSchedule,
            notes: result.notes,
            synced: false
        )
        newTemplate.markPendingSync()
        context.insert(newTemplate)
        insertExerciseTemplates(for: newTemplate, context: context)
    }

    private func createTemplate(context: ModelContext) -> WorkoutTemplate {
        let newTemplate = WorkoutTemplate(
            userId: userId,
            name: trimmedName,
            type: workoutType,
            exercises: [],
            estimatedMinutes: estimatedDraftMinutes,
            nextScheduledAt: futureScheduledDate(),
            notes: sessionNotes,
            synced: false
        )
        newTemplate.markPendingSync()
        context.insert(newTemplate)
        insertExerciseTemplates(for: newTemplate, context: context)
        return newTemplate
    }

    private func updateLoadedTemplate(_ template: WorkoutTemplate, context: ModelContext) {
        template.name = trimmedName
        template.type = workoutType
        template.notes = sessionNotes
        template.estimatedMinutes = estimatedDraftMinutes
        applyScheduledDate(to: template)
        replaceTemplateExercises(on: template, context: context)
        template.markPendingSync()
    }

    private var estimatedDraftMinutes: Int {
        max(30, min(120, exercises.count * 12))
    }

    private func futureScheduledDate() -> Date? {
        scheduledDate > .now ? scheduledDate : nil
    }

    private func applyScheduledDate(to template: WorkoutTemplate) {
        template.nextScheduledAt = futureScheduledDate()
    }

    private func refreshWorkoutReminder(for template: WorkoutTemplate) {
        Task {
            if template.nextScheduledAt != nil {
                await NotificationService.shared.scheduleWorkoutReminder(template: template)
            } else {
                await NotificationService.shared.cancelWorkoutReminder(templateId: template.id)
            }
        }
    }

    private func insertExerciseTemplates(for template: WorkoutTemplate, context: ModelContext) {
        for exercise in exercises.sorted(by: { $0.order < $1.order }) {
            let row = makeExerciseTemplate(from: exercise, template: template)
            context.insert(row)
            template.exercises.append(row)
        }
    }

    private func replaceTemplateExercises(on template: WorkoutTemplate, context: ModelContext) {
        for old in template.exercises {
            context.delete(old)
        }
        template.exercises.removeAll()
        insertExerciseTemplates(for: template, context: context)
    }

    private func makeExerciseTemplate(
        from exercise: BuilderDraftExercise,
        template: WorkoutTemplate
    ) -> ExerciseTemplate {
        ExerciseTemplate(
            templateId: template.id,
            name: exercise.name,
            category: exercise.category,
            type: exercise.type,
            defaultSets: exercise.defaultSets,
            defaultReps: exercise.defaultReps,
            defaultWeightKg: exercise.defaultWeightKg,
            defaultDurationSeconds: exercise.defaultDurationSeconds,
            defaultDistanceKm: exercise.defaultDistanceKm,
            order: exercise.order,
            notes: exercise.notes,
            supersetGroupId: exercise.supersetGroupId,
            template: template
        )
    }

    private func repeatDate(for result: WorkoutCompleteResult) -> Date? {
        let calendar = Calendar.current
        if let custom = result.customRepeatDate { return custom }
        guard let schedule = result.repeatSchedule else { return nil }
        switch schedule {
        case .nextDay:
            return calendar.date(byAdding: .day, value: 1, to: .now)
        case .in2Days:
            return calendar.date(byAdding: .day, value: 2, to: .now)
        case .in3Days:
            return calendar.date(byAdding: .day, value: 3, to: .now)
        case .nextWeekSameDay:
            return calendar.date(byAdding: .day, value: 7, to: .now)
        case .custom:
            return result.customRepeatDate
        }
    }

    private func recordSessionPR(exerciseName: String, newValue: String, previousValue: String?) {
        guard !sessionPRs.contains(where: { $0.exerciseName == exerciseName }) else { return }
        sessionPRs.append(
            WorkoutCompletePR(
                exerciseName: exerciseName,
                newValue: newValue,
                previousValue: previousValue
            )
        )
    }

    private func showPRToast(exerciseName: String, detail: String) {
        let toast = WorkoutPRToast(exerciseName: exerciseName, detail: detail)
        prToast = toast
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            try? await Task.sleep(for: .seconds(2.8))
            if prToast?.id == toast.id {
                prToast = nil
            }
        }
    }

    private func formatPRValue(_ record: PersonalRecord) -> String {
        switch record.unit {
        case "kg": return String(format: "%.0f kg", record.value)
        case "kg·reps": return String(format: "%.0f kg·reps", record.value)
        case "km": return String(format: "%.1f km", record.value)
        case "min/km": return String(format: "%.1f min/km", record.value)
        default: return String(format: "%.1f %@", record.value, record.unit)
        }
    }

    func endWorkout(context: ModelContext, syncService: SyncService) {
        prepareEndWorkout()
    }

    func paceLabel(duration: Int?, distance: Double?) -> String {
        guard let duration, let distance, distance > 0 else { return "—" }
        let paceMinutes = Double(duration) / 60.0 / distance
        let m = Int(paceMinutes)
        let s = Int((paceMinutes - Double(m)) * 60)
        return String(format: "%d:%02d min/km", m, s)
    }

    // MARK: - Private

    private func defaultRest(for type: ExerciseType) -> Int {
        let base: Int
        switch workoutType {
        case .cardio: base = 0
        case .bodyweight: base = 60
        default: base = 90
        }
        return ActivityEngine.recommendedRestSeconds(
            base: base,
            context: recoveryContext,
            workoutType: workoutType
        )
    }

    private func reindexExercises() {
        for index in exercises.indices {
            exercises[index].order = index
        }
    }

    private func initializeSetStates(context: ModelContext) {
        setStates = [:]
        for exercise in exercises {
            var sets: [BuilderSetState] = []
            let previous = previousSummary(for: exercise.name, context: context)

            if exercise.warmupSetsEnabled, exercise.type == .weighted || exercise.type == .bodyweight {
                sets.append(
                    BuilderSetState(
                        setNumber: 1,
                        reps: exercise.defaultReps,
                        weightKg: exercise.type == .weighted ? exercise.defaultWeightKg * 0.5 : 0,
                        isWarmup: true,
                        previousSummary: previous
                    )
                )
            }

            let workingCount = max(exercise.defaultSets, 1)
            for _ in 0..<workingCount {
                let number = sets.count + 1
                let duration: Int? = {
                    if exercise.type == .timed {
                        return exercise.defaultDurationSeconds > 0 ? exercise.defaultDurationSeconds : nil
                    }
                    guard exercise.type == .cardio else { return nil }
                    guard exercise.cardioMode != .distance else { return nil }
                    return exercise.defaultDurationSeconds > 0 ? exercise.defaultDurationSeconds : nil
                }()
                let distance: Double? = {
                    guard exercise.type == .cardio else { return nil }
                    guard exercise.cardioMode != .duration else { return nil }
                    return exercise.defaultDistanceKm > 0 ? exercise.defaultDistanceKm : nil
                }()
                sets.append(
                    BuilderSetState(
                        setNumber: number,
                        reps: exercise.type == .cardio || exercise.type == .timed ? nil : exercise.defaultReps,
                        weightKg: exercise.type == .bodyweight ? 0 : exercise.defaultWeightKg,
                        durationSeconds: duration,
                        distanceKm: distance,
                        previousSummary: previous
                    )
                )
            }
            setStates[exercise.id] = sets
            restDuration = exercise.restSeconds
        }
    }

    private func previousSummary(for exerciseName: String, context: ModelContext) -> String {
        let name = exerciseName
        let userIdConst = userId
        var descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate { set in
                set.exerciseName == name && set.userId == userIdConst
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let last = try? context.fetch(descriptor).first else { return "—" }
        if let reps = last.reps, let weight = last.weightKg {
            return "\(reps) × \(Int(weight))"
        }
        if let duration = last.durationSeconds {
            let m = duration / 60
            let s = duration % 60
            return String(format: "%d:%02d", m, s)
        }
        return "—"
    }

    private func mutateSet(setId: UUID, exerciseId: UUID, _ update: (inout BuilderSetState) -> Void) {
        guard var sets = setStates[exerciseId],
              let index = sets.firstIndex(where: { $0.id == setId }) else { return }
        update(&sets[index])
        setStates[exerciseId] = sets
    }

    private func startElapsedTimer() {
        elapsedTask?.cancel()
        elapsedTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if let startedAt {
                    elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
                    updateLiveActivity(restSeconds: showRestTimer ? restSecondsRemaining : nil)
                }
            }
        }
    }

    private func startRest(seconds: Int) {
        restDuration = seconds
        restSecondsRemaining = seconds
        showRestTimer = true
        updateLiveActivity(restSeconds: seconds)
        restTask?.cancel()
        restTask = Task {
            var remaining = seconds
            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remaining -= 1
                restSecondsRemaining = remaining
                updateLiveActivity(restSeconds: remaining)
                if remaining == 10 {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showRestTimer = false
            updateLiveActivity(restSeconds: nil)
        }
    }

    private func updateLiveActivity(restSeconds: Int?) {
        guard screenPhase == .active else { return }
        let exercise = exercises[safe: currentExerciseIndex]
        let completedSets = setStates[exercise?.id ?? UUID()]?.filter(\.isCompleted).count ?? 0
        WorkoutLiveActivityManager.update(
            exerciseName: exercise?.name ?? trimmedName,
            setLabel: "Set \(completedSets + 1)",
            restSecondsRemaining: restSeconds,
            elapsedSeconds: elapsedSeconds
        )
    }

    private func loadVolumeProgressHints(context: ModelContext) {
        volumeProgressHints = [:]
        for exercise in exercises where exercise.type == .weighted {
            if let hint = WorkoutAnalytics.volumeProgressHint(
                exerciseName: exercise.name,
                userId: userId,
                context: context
            ) {
                volumeProgressHints[exercise.id] = hint
            }
        }
    }

    private func loadProfileWeight(context: ModelContext) {
        let userIdConst = userId
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userIdConst }
        )
        if let profile = try? context.fetch(descriptor).first, profile.weightKg > 0 {
            profileBodyWeightKg = profile.weightKg
        }
    }

    private func supersetPartnerIndex(for exerciseId: UUID) -> Int? {
        guard let exercise = exercises.first(where: { $0.id == exerciseId }),
              let groupId = exercise.supersetGroupId else { return nil }
        return exercises.firstIndex(where: { $0.id != exerciseId && $0.supersetGroupId == groupId })
    }

    private func shouldSkipRestAfterSuperset(completedExerciseId: UUID, completedSetNumber: Int) -> Bool {
        guard let partnerIndex = supersetPartnerIndex(for: completedExerciseId),
              let partner = exercises[safe: partnerIndex],
              let partnerSets = setStates[partner.id] else { return false }
        return partnerSets.contains(where: { !$0.isCompleted && $0.setNumber == completedSetNumber })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
