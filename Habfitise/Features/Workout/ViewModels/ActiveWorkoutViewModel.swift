import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit

@Observable
@MainActor
final class ActiveWorkoutViewModel: Identifiable {
    var id: UUID { sessionId }

    let userId: String
    let workoutName: String
    let sessionId: UUID

    var phase: ActiveWorkoutPhase = .idle
    var sessionExercises: [SessionExercise]
    var chartTimeRange: ChartTimeRange = .day

    var currentReps: Int
    var currentWeightKg: Double
    var editingField: ActiveWorkoutInputField?

    var lastCompletedSet: CompletedSetSnapshot?
    var showRestTimer = false
    var showCompletionSheet = false
    var completionStats: WorkoutCompletionStats?

    var lastTimeSummary: String = "Last time: 3 × 10 @ 60 kg"
    var gearRotation: Double = 0

    private let restDurationSeconds = 90
    private let workoutStartTime = Date()
    private var restTimerTask: Task<Void, Never>?
    private var gearAnimationTask: Task<Void, Never>?
    private var postRestPhase: ActiveWorkoutPhase = .idle

    init(userId: String, workoutName: String, exercises: [SessionExercise]) {
        self.userId = userId
        self.workoutName = workoutName
        self.sessionId = UUID()
        self.sessionExercises = exercises

        let first = exercises.first
        self.currentReps = first?.targetReps ?? 10
        self.currentWeightKg = first?.targetWeightKg ?? 60

        self.phase = .active(exerciseIndex: 0, setIndex: 1)
    }

    // MARK: - Derived State

    var currentExerciseIndex: Int {
        if case let .active(index, _) = phase { return index }
        if case .resting = phase, case let .active(index, _) = postRestPhase { return index }
        return 0
    }

    var currentSetIndex: Int {
        if case let .active(_, setIndex) = phase { return setIndex }
        return sessionExercises[safe: currentExerciseIndex]?.setsCompleted ?? 1
    }

    var exerciseName: String {
        sessionExercises[safe: currentExerciseIndex]?.name ?? workoutName
    }

    var totalSetsForCurrentExercise: Int {
        sessionExercises[safe: currentExerciseIndex]?.totalSets ?? 1
    }

    var exerciseProgressLabel: String {
        "Exercise \(min(currentExerciseIndex + 1, sessionExercises.count)) of \(sessionExercises.count)"
    }

    var currentProgress: Double {
        let totalSets = sessionExercises.reduce(0) { $0 + $1.totalSets }
        let completedSets = sessionExercises.reduce(0) { $0 + $1.setsCompleted }
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }

    var completionPercent: Int {
        Int((currentProgress * 100).rounded())
    }

    var timerString: String {
        if case let .resting(seconds) = phase {
            let minutes = seconds / 60
            let secs = seconds % 60
            return String(format: "%d:%02d", minutes, secs)
        }
        return "—"
    }

    var restCountdownString: String {
        if case let .resting(seconds) = phase {
            let minutes = seconds / 60
            let secs = seconds % 60
            return String(format: "%d:%02d", minutes, secs)
        }
        return "1:30"
    }

    var restProgress: Double {
        if case let .resting(seconds) = phase {
            return Double(seconds) / Double(restDurationSeconds)
        }
        return 1
    }

    var chartExercises: [SessionExercise] {
        Array(sessionExercises.prefix(7))
    }

    var yAxisLabels: [String] {
        switch chartTimeRange {
        case .day:
            return ["800", "1.6K", "2.4K", "3.2K", "4K"]
        case .week:
            return ["2K", "4K", "6K", "8K", "10K"]
        }
    }

    // MARK: - Lifecycle

    func onAppear(context: ModelContext) {
        startGearAnimation()
        refreshLastTimeSummary(context: context)
    }

    func onDisappear() {
        restTimerTask?.cancel()
        gearAnimationTask?.cancel()
    }

    // MARK: - Input

    func toggleEditing(_ field: ActiveWorkoutInputField) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            editingField = editingField == field ? nil : field
        }
    }

    func incrementReps() {
        currentReps += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func decrementReps() {
        currentReps = max(currentReps - 1, 1)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func incrementWeight() {
        currentWeightKg += 2.5
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func decrementWeight() {
        currentWeightKg = max(currentWeightKg - 2.5, 0)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Done Set

    func completeCurrentSet(context: ModelContext, syncService: SyncService) {
        guard case let .active(exerciseIndex, setIndex) = phase else { return }

        let exercise = sessionExercises[exerciseIndex]
        let set = ExerciseSet(
            sessionId: sessionId,
            userId: userId,
            exerciseName: exercise.name,
            setNumber: setIndex,
            reps: currentReps,
            weightKg: currentWeightKg,
            synced: false
        )
        context.insert(set)
        try? context.save()

        lastCompletedSet = CompletedSetSnapshot(
            exerciseName: exercise.name,
            setNumber: setIndex,
            reps: currentReps,
            weightKg: currentWeightKg
        )

        sessionExercises[exerciseIndex].setsCompleted += 1
        sessionExercises[exerciseIndex].loggedVolumeKg += Double(currentReps) * currentWeightKg
        sessionExercises[exerciseIndex].maxLoggedWeightKg = max(
            sessionExercises[exerciseIndex].maxLoggedWeightKg,
            currentWeightKg
        )

        if setIndex >= exercise.totalSets {
            advanceToNextExercise(from: exerciseIndex)
        } else {
            phase = .active(exerciseIndex: exerciseIndex, setIndex: setIndex + 1)
        }

        if case .complete = phase {
            endWorkout(context: context, syncService: syncService)
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            showRestTimer = true
        }

        startRestTimer()
        refreshLastTimeSummary(context: context)
    }

    func skipRest() {
        restTimerTask?.cancel()
        finishRest()
    }

    func jumpToExercise(at index: Int) {
        guard sessionExercises.indices.contains(index) else { return }

        restTimerTask?.cancel()
        showRestTimer = false

        let exercise = sessionExercises[index]
        currentReps = exercise.targetReps
        currentWeightKg = exercise.targetWeightKg

        let nextSet = min(max(exercise.setsCompleted + 1, 1), exercise.totalSets)
        phase = .active(exerciseIndex: index, setIndex: nextSet)
    }

    func endWorkout(context: ModelContext, syncService: SyncService) {
        guard !showCompletionSheet else { return }

        restTimerTask?.cancel()

        let duration = Int(Date().timeIntervalSince(workoutStartTime))
        let totalSets = sessionExercises.reduce(0) { $0 + $1.setsCompleted }
        let totalVolume = sessionExercises.reduce(0) { $0 + $1.volumeKg }

        let session = WorkoutSession(
            id: sessionId,
            userId: userId.lowercased(),
            name: workoutName,
            type: .weights,
            startedAt: workoutStartTime,
            completedAt: .now,
            durationSeconds: duration,
            totalVolumeKg: totalVolume,
            notes: workoutName,
            synced: false
        )
        context.insert(session)
        session.markPendingSync()
        try? context.save()

        completionStats = WorkoutCompletionStats(
            durationSeconds: duration,
            totalSets: totalSets,
            totalVolumeKg: totalVolume,
            newPRs: detectPRs(context: context)
        )

        phase = .complete
        showRestTimer = false
        showCompletionSheet = true

        syncService.schedulePush(modelContext: context, userId: userId.lowercased())
    }

    // MARK: - Private

    private func advanceToNextExercise(from index: Int) {
        let next = index + 1
        if next < sessionExercises.count {
            currentReps = sessionExercises[next].targetReps
            currentWeightKg = sessionExercises[next].targetWeightKg
            phase = .active(exerciseIndex: next, setIndex: 1)
        } else {
            phase = .complete
            showRestTimer = false
        }
    }

    private func startRestTimer() {
        restTimerTask?.cancel()

        if case .active = phase {
            postRestPhase = phase
        }

        phase = .resting(secondsRemaining: restDurationSeconds)

        restTimerTask = Task {
            var remaining = restDurationSeconds
            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remaining -= 1
                phase = .resting(secondsRemaining: remaining)

                if remaining == 10 {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }

            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            finishRest()
        }
    }

    private func finishRest() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            showRestTimer = false
        }

        if case .complete = phase { return }

        if case .active = postRestPhase {
            phase = postRestPhase
        }
    }

    private func startGearAnimation() {
        gearAnimationTask?.cancel()
        gearAnimationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 2)) {
                    gearRotation += 360
                }
            }
        }
    }

    private func refreshLastTimeSummary(context: ModelContext) {
        let exerciseNameConst = exerciseName
        let userIdConst = userId
        let sessionIdConst = sessionId
        var descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate { set in
                set.exerciseName == exerciseNameConst
                    && set.userId == userIdConst
                    && set.sessionId != sessionIdConst
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        guard let sets = try? context.fetch(descriptor), !sets.isEmpty else {
            lastTimeSummary = "Last time: —"
            return
        }

        let latestSessionId = sets.first?.sessionId
        let previousSets = sets
            .filter { $0.sessionId == latestSessionId }
            .sorted { $0.setNumber < $1.setNumber }

        guard let first = previousSets.first else {
            lastTimeSummary = "Last time: —"
            return
        }

        let setCount = previousSets.count
        let reps = first.reps ?? 0
        let weight = Int(first.weightKg ?? 0)
        lastTimeSummary = "Last time: \(setCount) × \(reps) @ \(weight) kg"
    }

    private func detectPRs(context: ModelContext) -> [WorkoutPersonalRecord] {
        var records: [WorkoutPersonalRecord] = []
        let userIdConst = userId
        let sessionIdConst = sessionId

        for exercise in sessionExercises where exercise.setsCompleted > 0 {
            let nameConst = exercise.name
            var descriptor = FetchDescriptor<ExerciseSet>(
                predicate: #Predicate { set in
                    set.exerciseName == nameConst
                        && set.userId == userIdConst
                        && set.sessionId != sessionIdConst
                },
                sortBy: [SortDescriptor(\.weightKg, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            let historicalBest = (try? context.fetch(descriptor))?.first?.weightKg ?? 0
            let sessionBest = exercise.maxLoggedWeightKg

            if sessionBest > historicalBest {
                records.append(
                    WorkoutPersonalRecord(
                        exerciseName: exercise.name,
                        detail: "\(Int(sessionBest)) kg PR"
                    )
                )
            }
        }

        return records
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
