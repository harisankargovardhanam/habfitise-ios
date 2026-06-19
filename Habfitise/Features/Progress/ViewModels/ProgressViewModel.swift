import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ProgressViewModel {
    var workoutCount = 0
    var habitCompletionRate = 0.0
    var tasksCompleted = 0
    var weeklyWorkoutMinutes: [Double] = Array(repeating: 0, count: 7)
    var personalRecords: [ProgressPersonalRecord] = []
    var heatmapCells: [HabitHeatmapCell] = []
    var waterWeekDays: [WaterWeekDay] = []
    var waterDailyAverage = 0
    var waterGoalML = AppConstants.Water.defaultDailyGoalML

    func bind(
        userId: String,
        sessions: [WorkoutSession],
        sets: [ExerciseSet],
        habits: [Habit],
        completions: [HabitCompletion],
        tasks: [TaskRecord],
        waterLogs: [WaterLog],
        waterGoal: WaterGoal?,
        isPro: Bool,
        context: ModelContext
    ) {
        let completedSessions = sessions.filter { $0.completedAt != nil }

        let calendar = Calendar.current
        if let monthInterval = calendar.dateInterval(of: .month, for: .now) {
            workoutCount = completedSessions.filter { session in
                guard let completedAt = session.completedAt else { return false }
                return completedAt >= monthInterval.start && completedAt < monthInterval.end
            }.count
        } else {
            workoutCount = completedSessions.count
        }

        tasksCompleted = tasks.filter(\.isComplete).count

        let weekStart = ProgressAnalytics.mondayStart(for: .now, calendar: calendar)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }

        weeklyWorkoutMinutes = (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return 0 }
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let minutes = completedSessions
                .filter { session in
                    guard let completedAt = session.completedAt else { return false }
                    return completedAt >= dayStart && completedAt < dayEnd
                }
                .reduce(0) { $0 + max($1.durationSeconds / 60, 0) }

            return Double(minutes)
        }

        habitCompletionRate = computeHabitRate(
            habits: habits,
            completions: completions,
            weekStart: weekStart,
            weekEnd: weekEnd
        )

        personalRecords = {
            let userIdConst = userId
            let descriptor = FetchDescriptor<PersonalRecord>(
                predicate: #Predicate { $0.userId == userIdConst },
                sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
            )
            let stored = (try? context.fetch(descriptor)) ?? []
            return ProgressAnalytics.personalRecords(fromStored: stored)
        }()

        let heatmapWeeks = isPro ? 10 : 4
        let heatmapStart = calendar.date(byAdding: .weekOfYear, value: -heatmapWeeks, to: .now) ?? weekStart
        let rangeCompletions = completions.filter { $0.completedDate >= heatmapStart }
        heatmapCells = ProgressAnalytics.habitHeatmap(
            habits: habits,
            completions: rangeCompletions,
            weeks: heatmapWeeks,
            calendar: calendar
        )

        waterGoalML = waterGoal?.dailyGoalMl ?? AppConstants.Water.defaultDailyGoalML
        let weekLogs = waterLogs.filter { $0.loggedAt >= weekStart && $0.loggedAt < weekEnd }
        waterWeekDays = ProgressAnalytics.waterWeekDays(logs: weekLogs, goalMl: waterGoalML, calendar: calendar)

        let daysWithData = max(waterWeekDays.filter { $0.amountMl > 0 }.count, 1)
        let totalWater = waterWeekDays.reduce(0) { $0 + $1.amountMl }
        waterDailyAverage = totalWater / daysWithData

        _ = context
        _ = userId
    }

    func generateCSV(
        sessions: [WorkoutSession],
        sets: [ExerciseSet],
        habits: [Habit],
        completions: [HabitCompletion],
        tasks: [TaskRecord],
        waterLogs: [WaterLog]
    ) -> String {
        var lines = ["type,name,detail,date"]

        for session in sessions {
            let date = (session.completedAt ?? session.startedAt).ISO8601Format()
            lines.append("workout,\(csvEscape(session.name)),\(session.durationSeconds)s,\(date)")
        }

        for set in sets {
            let detail: String
            if let weight = set.weightKg, let reps = set.reps {
                detail = "\(weight)kg×\(reps)"
            } else if let duration = set.durationSeconds {
                detail = "\(duration)s"
            } else {
                detail = "logged"
            }
            lines.append("set,\(csvEscape(set.exerciseName)),\(detail),\(set.completedAt.ISO8601Format())")
        }

        for habit in habits {
            lines.append("habit,\(csvEscape(habit.name)),\(habit.frequency),\(habit.createdAt.ISO8601Format())")
        }

        for completion in completions {
            lines.append("habit_completion,\(completion.habitId.uuidString),done,\(completion.completedDate.ISO8601Format())")
        }

        for task in tasks {
            lines.append("task,\(csvEscape(task.title)),\(task.isComplete ? "complete" : "open"),\(task.updatedAt.ISO8601Format())")
        }

        for log in waterLogs {
            lines.append("water,,\(log.amountMl)ml,\(log.loggedAt.ISO8601Format())")
        }

        return lines.joined(separator: "\n")
    }

    func exportFileURL(
        sessions: [WorkoutSession],
        sets: [ExerciseSet],
        habits: [Habit],
        completions: [HabitCompletion],
        tasks: [TaskRecord],
        waterLogs: [WaterLog]
    ) -> URL {
        let csv = generateCSV(
            sessions: sessions,
            sets: sets,
            habits: habits,
            completions: completions,
            tasks: tasks,
            waterLogs: waterLogs
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("habfitise-export-\(Int(Date().timeIntervalSince1970)).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func computeHabitRate(
        habits: [Habit],
        completions: [HabitCompletion],
        weekStart: Date,
        weekEnd: Date
    ) -> Double {
        let active = habits.filter(\.isActive)
        guard !active.isEmpty else { return 0 }

        let calendar = Calendar.current
        var expected = 0
        var completed = 0

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            for habit in active {
                expected += 1
                if completions.contains(where: { completion in
                    completion.habitId == habit.id
                        && completion.completedDate >= dayStart
                        && completion.completedDate < dayEnd
                }) {
                    completed += 1
                }
            }
        }

        guard expected > 0 else { return 0 }
        return Double(completed) / Double(expected)
    }

    private func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
