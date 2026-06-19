import Foundation
import SwiftData

// MARK: - Models

struct VolumeProgressHint: Equatable {
    let message: String
    let colorHex: String
}

struct WorkoutStreakStats: Equatable {
    let currentStreak: Int
    let bestStreak: Int
    let monthCompleted: Int
    let monthPlanned: Int
    let consistency30Day: Double

    var hasActiveStreak: Bool { currentStreak > 0 }
}

struct WorkoutSuggestion: Equatable {
    let name: String
    let type: WorkoutType
    let reason: String
}

struct OneRMHistoryPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let valueKg: Double
}

// MARK: - Analytics

@MainActor
enum WorkoutAnalytics {
    static func epleyOneRM(weightKg: Double, reps: Int) -> Double {
        guard reps > 0, weightKg > 0 else { return 0 }
        return (weightKg * (1 + Double(reps) / 30) * 10).rounded() / 10
    }

    static func estimatedCalories(
        workoutType: WorkoutType,
        durationSeconds: Int,
        bodyWeightKg: Double
    ) -> Int {
        guard durationSeconds > 0, bodyWeightKg > 0 else { return 0 }
        let hours = Double(durationSeconds) / 3600
        let met: Double
        switch workoutType {
        case .weights: met = 5.0
        case .cardio: met = 7.5
        case .hiit: met = 9.0
        case .bodyweight: met = 4.0
        case .flexibility: met = 2.5
        }
        return Int((met * bodyWeightKg * hours).rounded())
    }

    static func volumeProgressHint(
        exerciseName: String,
        userId: String,
        context: ModelContext
    ) -> VolumeProgressHint? {
        guard let lastWeight = lastWorkingWeight(exerciseName: exerciseName, userId: userId, context: context) else {
            return nil
        }

        let rpe = lastSessionRPE(forExercise: exerciseName, userId: userId, context: context) ?? 7

        if rpe <= 6 {
            let target = (lastWeight + 2.5 * 10).rounded() / 10
            return VolumeProgressHint(
                message: "↑ Try +2.5 kg today (\(Int(target)) kg)",
                colorHex: "#22C55E"
            )
        }
        if rpe <= 8 {
            return VolumeProgressHint(
                message: "= Same as last time (\(formatWeight(lastWeight)))",
                colorHex: "#9CA3AF"
            )
        }
        return VolumeProgressHint(
            message: "↓ Lighter today is fine",
            colorHex: "#3B82F6"
        )
    }

    static func streakStats(userId: String, context: ModelContext) -> WorkoutStreakStats {
        let calendar = Calendar.current
        let userIdConst = userId
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.userId == userIdConst && $0.completedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []

        let workoutDays = Set(sessions.compactMap { session -> Date? in
            guard let completed = session.completedAt else { return nil }
            return calendar.startOfDay(for: completed)
        }).sorted(by: >)

        let current = currentStreak(from: workoutDays, calendar: calendar)
        let best = bestStreak(from: workoutDays, calendar: calendar)

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let monthCompleted = sessions.filter { ($0.completedAt ?? $0.startedAt) >= monthStart }.count
        let monthPlanned = 16

        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recentCount = sessions.filter { ($0.completedAt ?? $0.startedAt) >= thirtyDaysAgo }.count
        let target30 = 12.0
        let consistency = min(Double(recentCount) / target30, 1.0)

        return WorkoutStreakStats(
            currentStreak: current,
            bestStreak: best,
            monthCompleted: monthCompleted,
            monthPlanned: monthPlanned,
            consistency30Day: consistency
        )
    }

    static func oneRMHistory(
        exerciseName: String,
        userId: String,
        context: ModelContext,
        weeks: Int = 8
    ) -> [OneRMHistoryPoint] {
        let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: .now) ?? .now
        let name = exerciseName
        let userIdConst = userId
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate { set in
                set.userId == userIdConst
                    && set.exerciseName == name
                    && set.completedAt >= cutoff
                    && set.isWarmup == false
            },
            sortBy: [SortDescriptor(\.completedAt)]
        )
        let sets = (try? context.fetch(descriptor)) ?? []

        var byDay: [Date: Double] = [:]
        for set in sets {
            guard let weight = set.weightKg, let reps = set.reps, reps > 0 else { continue }
            let day = Calendar.current.startOfDay(for: set.completedAt)
            let estimate = epleyOneRM(weightKg: weight, reps: reps)
            byDay[day] = max(byDay[day] ?? 0, estimate)
        }

        return byDay.keys.sorted().map { day in
            OneRMHistoryPoint(id: UUID(), date: day, valueKg: byDay[day] ?? 0)
        }
    }

    static func storeEstimatedOneRMIfNeeded(
        exerciseName: String,
        weightKg: Double,
        reps: Int,
        sessionId: UUID,
        userId: String,
        context: ModelContext
    ) -> Double? {
        let estimate = epleyOneRM(weightKg: weightKg, reps: reps)
        guard estimate > 0 else { return nil }

        if let existing = SwiftDataStack.shared.fetchPR(userId: userId, exerciseName: exerciseName, type: .maxWeight),
           estimate <= existing.value {
            return estimate
        }

        let record = PersonalRecord(
            userId: userId,
            exerciseName: exerciseName,
            recordType: .maxWeight,
            value: estimate,
            unit: "kg",
            achievedAt: .now,
            sessionId: sessionId,
            synced: false
        )
        context.insert(record)
        return estimate
    }

    static func localWorkoutSuggestion(
        sessions: [WorkoutSession],
        sets: [ExerciseSet]
    ) -> WorkoutSuggestion? {
        let completed = sessions.filter { $0.completedAt != nil }.prefix(4)
        guard completed.count >= 4 else { return nil }

        let typeCounts = Dictionary(grouping: completed, by: \.type).mapValues(\.count)
        let dominant = typeCounts.max(by: { $0.value < $1.value })?.key ?? .weights

        let topExercise = Dictionary(grouping: sets, by: \.exerciseName)
            .max(by: { $0.value.count < $1.value.count })?
            .key

        switch dominant {
        case .cardio:
            return WorkoutSuggestion(
                name: "Steady State Cardio",
                type: .cardio,
                reason: "You've been consistent with cardio lately"
            )
        case .bodyweight:
            return WorkoutSuggestion(
                name: "Bodyweight Circuit",
                type: .bodyweight,
                reason: "Matches your recent training style"
            )
        case .hiit:
            return WorkoutSuggestion(
                name: "HIIT Power Session",
                type: .hiit,
                reason: "Based on your recent HIIT sessions"
            )
        default:
            let name = topExercise.map { "\($0) Focus" } ?? "Upper Body Strength"
            return WorkoutSuggestion(
                name: name,
                type: .weights,
                reason: "Based on your last 4 sessions"
            )
        }
    }

    // MARK: - Private

    private static func lastWorkingWeight(
        exerciseName: String,
        userId: String,
        context: ModelContext
    ) -> Double? {
        let name = exerciseName
        let userIdConst = userId
        var descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate { set in
                set.exerciseName == name && set.userId == userIdConst && set.isWarmup == false
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        let sets = (try? context.fetch(descriptor)) ?? []
        return sets.compactMap(\.weightKg).max()
    }

    private static func lastSessionRPE(
        forExercise exerciseName: String,
        userId: String,
        context: ModelContext
    ) -> Int? {
        let name = exerciseName
        let userIdConst = userId
        var setDescriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate { $0.exerciseName == name && $0.userId == userIdConst },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        setDescriptor.fetchLimit = 1
        guard let lastSet = try? context.fetch(setDescriptor).first else { return nil }

        let sessionId = lastSet.sessionId
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == sessionId }
        )
        guard let session = try? context.fetch(sessionDescriptor).first else { return nil }
        return session.perceivedExertion > 0 ? session.perceivedExertion : nil
    }

    private static func currentStreak(from days: [Date], calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            if !days.contains(yesterday) { return 0 }
            cursor = yesterday
        }

        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private static func bestStreak(from days: [Date], calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var best = 1
        var run = 1
        for index in 1..<sorted.count {
            let delta = calendar.dateComponents([.day], from: sorted[index - 1], to: sorted[index]).day ?? 0
            if delta == 1 {
                run += 1
                best = max(best, run)
            } else if delta > 1 {
                run = 1
            }
        }
        return best
    }

    private static func formatWeight(_ kg: Double) -> String {
        String(format: "%.1f kg", kg)
    }
}
