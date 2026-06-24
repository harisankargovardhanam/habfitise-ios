import Foundation
import SwiftData

enum ActivityEngine {
    static let exerciseGoalMinutes = AppConstants.Health.defaultExerciseGoalMinutes

    // MARK: - Daily summary

    static func dailySummary(
        health: HomeHealthSnapshot,
        todaySessions: [WorkoutSession]
    ) -> DailyActivitySummary {
        let completed = todaySessions.filter { $0.completedAt != nil }
        let workoutMinutes = completed.reduce(0) { $0 + max($1.durationSeconds / 60, 0) }
        let volume = completed.reduce(0) { $0 + $1.totalVolumeKg }
        let combinedExercise = max(health.exerciseMinutes, workoutMinutes)

        return DailyActivitySummary(
            health: health,
            workoutMinutesToday: workoutMinutes,
            workoutVolumeKg: volume,
            hasCompletedWorkoutToday: !completed.isEmpty,
            combinedExerciseMinutes: combinedExercise
        )
    }

    // MARK: - Smart suggestions

    static func suggestWorkout(
        health: HomeHealthSnapshot,
        templates: [WorkoutTemplate],
        todaySessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> SmartWorkoutSuggestion? {
        if todaySessions.contains(where: { $0.completedAt != nil }) { return nil }

        let hour = calendar.component(.hour, from: .now)
        let steps = health.steps
        let stepGoal = health.stepGoal

        if let scheduled = templates
            .filter({ isScheduledToday($0, calendar: calendar) })
            .sorted(by: { ($0.nextScheduledAt ?? .distantFuture) < ($1.nextScheduledAt ?? .distantFuture) })
            .first {
            return SmartWorkoutSuggestion(
                type: scheduled.type,
                reason: "\(scheduled.name) is on your schedule"
            )
        }

        if hour >= 15, steps < stepGoal / 2 {
            return SmartWorkoutSuggestion(
                type: .cardio,
                reason: "Low steps today — a walk or cardio session helps"
            )
        }

        if health.exerciseMinutes >= exerciseGoalMinutes {
            return SmartWorkoutSuggestion(
                type: .bodyweight,
                reason: "Active day — light bodyweight work fits well"
            )
        }

        if calendar.component(.weekday, from: .now) == 1 {
            return SmartWorkoutSuggestion(
                type: .weights,
                reason: "Start the week with strength"
            )
        }

        return SmartWorkoutSuggestion(
            type: .weights,
            reason: "Balanced day — strength training recommended"
        )
    }

    // MARK: - Daily brief

    static func dailyBrief(
        summary: DailyActivitySummary,
        wellness: WellnessScore,
        habitsDone: Int,
        habitsTotal: Int,
        openTasks: Int
    ) -> DailyBrief {
        let hour = Calendar.current.component(.hour, from: .now)

        if summary.hasCompletedWorkoutToday {
            let steps = summary.health.steps.formatted()
            return DailyBrief(line: "Workout done · \(steps) steps today · wellness \(wellness.score)%")
        }

        if hour < 12 {
            if habitsTotal > 0, habitsDone == 0 {
                return DailyBrief(line: "\(habitsTotal) habits due · \(summary.health.steps.formatted()) steps so far")
            }
            return DailyBrief(line: "\(summary.health.steps.formatted()) steps · \(Int(summary.stepProgress * 100))% of step goal")
        }

        if hour >= 17, !summary.hasCompletedWorkoutToday {
            return DailyBrief(line: "No workout yet · \(openTasks) open tasks · Move ring \(Int(summary.exerciseProgress * 100))%")
        }

        return DailyBrief(line: "\(summary.combinedExerciseMinutes) exercise min · wellness \(wellness.score)%")
    }

    // MARK: - Wellness

    static func wellnessScore(
        summary: DailyActivitySummary,
        habitsDone: Int,
        habitsTotal: Int,
        waterProgress: Double
    ) -> WellnessScore {
        let workoutPoints: Int = {
            if summary.hasCompletedWorkoutToday { return 30 }
            if summary.workoutMinutesToday > 0 { return 15 }
            return 0
        }()

        let stepsPoints = Int(summary.stepProgress * 30)
        let habitsPoints: Int = {
            guard habitsTotal > 0 else { return 10 }
            return Int(Double(habitsDone) / Double(habitsTotal) * 25)
        }()
        let waterPoints = Int(min(waterProgress, 1) * 15)

        let score = min(workoutPoints + stepsPoints + habitsPoints + waterPoints, 100)
        return WellnessScore(
            score: score,
            workoutPoints: workoutPoints,
            stepsPoints: stepsPoints,
            habitsPoints: habitsPoints,
            waterPoints: waterPoints
        )
    }

    // MARK: - Trends

    static func weeklyTrainingTrend(
        sessions: [WorkoutSession],
        weeklySteps: [Int],
        calendar: Calendar = .current
    ) -> [TrainingTrendDay] {
        let today = calendar.startOfDay(for: .now)
        let symbols = calendar.shortWeekdaySymbols
        let completed = sessions.filter { $0.completedAt != nil }

        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return TrainingTrendDay(id: "\(offset)", label: "-", workoutMinutes: 0, steps: 0, isToday: false)
            }
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let minutes = completed
                .filter { session in
                    guard let completedAt = session.completedAt else { return false }
                    return completedAt >= day && completedAt < next
                }
                .reduce(0) { $0 + max($1.durationSeconds / 60, 0) }

            let weekday = calendar.component(.weekday, from: day) - 1
            let label = String(symbols[weekday].prefix(2))
            let steps = weeklySteps[safe: offset] ?? 0

            return TrainingTrendDay(
                id: "\(offset)",
                label: label,
                workoutMinutes: Double(minutes),
                steps: steps,
                isToday: calendar.isDate(day, inSameDayAs: today)
            )
        }
    }

    // MARK: - Recovery

    static func recommendedRestSeconds(
        base: Int,
        context: RecoveryContext,
        workoutType: WorkoutType
    ) -> Int {
        guard workoutType != .cardio else { return 0 }

        var rest = base
        if context.yesterdayVolumeKg >= 5_000 {
            rest += 15
        } else if context.yesterdayVolumeKg >= 2_500 {
            rest += 10
        }

        if context.healthExerciseMinutes >= exerciseGoalMinutes {
            rest += 15
        } else if context.healthExerciseMinutes >= exerciseGoalMinutes / 2 {
            rest += 5
        }

        return min(rest, 180)
    }

    static func recoveryContext(
        health: HomeHealthSnapshot,
        yesterdaySessions: [WorkoutSession]
    ) -> RecoveryContext {
        let volume = yesterdaySessions
            .filter { $0.completedAt != nil }
            .reduce(0) { $0 + $1.totalVolumeKg }

        return RecoveryContext(
            healthExerciseMinutes: health.exerciseMinutes,
            yesterdayVolumeKg: volume
        )
    }

    static func yesterdaySessions(userId: String, context: ModelContext) -> [WorkoutSession] {
        let calendar = Calendar.current
        guard
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now)),
            let today = calendar.date(byAdding: .day, value: 1, to: yesterday)
        else { return [] }

        let userIdConst = userId.lowercased()
        let start = yesterday
        let end = today
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.userId == userIdConst
                    && session.startedAt >= start
                    && session.startedAt < end
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Copy helpers

    static func todayHealthSummaryLine(summary: DailyActivitySummary) -> String {
        "\(summary.health.activeEnergyKcal) kcal Move · \(summary.combinedExerciseMinutes) min Exercise · \(summary.health.steps.formatted()) steps"
    }

    static func prContextLine(steps: Int) -> String? {
        guard steps > 0 else { return nil }
        return "On a \(steps.formatted())-step day"
    }

    // MARK: - Private

    private static func isScheduledToday(_ template: WorkoutTemplate, calendar: Calendar) -> Bool {
        guard let scheduled = template.nextScheduledAt else { return false }
        return calendar.isDateInToday(scheduled)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
