import Foundation

struct ProgressPersonalRecord: Identifiable {
    let id: String
    let exerciseName: String
    let weightKg: Double
    let reps: Int
    let weeklyChangeKg: Double?
    let isNewPRThisWeek: Bool
    let valueLabel: String?

    var volume: Double { weightKg * Double(reps) }

    init(
        id: String,
        exerciseName: String,
        weightKg: Double,
        reps: Int,
        weeklyChangeKg: Double?,
        isNewPRThisWeek: Bool,
        valueLabel: String? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.weeklyChangeKg = weeklyChangeKg
        self.isNewPRThisWeek = isNewPRThisWeek
        self.valueLabel = valueLabel
    }
}

struct HabitHeatmapCell: Identifiable {
    let id: Date
    let date: Date
    let completionRate: Double
    let weekIndex: Int
}

struct WaterWeekDay: Identifiable {
    let id: Int
    let label: String
    let amountMl: Int
    let goalMl: Int

    var fillRatio: Double {
        guard goalMl > 0 else { return 0 }
        return min(Double(amountMl) / Double(goalMl), 1)
    }
}

enum ProgressAnalytics {
    static func personalRecords(fromStored records: [PersonalRecord]) -> [ProgressPersonalRecord] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }

        return records.prefix(5).map { record in
            let isNewThisWeek = record.achievedAt >= weekStart
            let (weightKg, reps, valueLabel) = displayValues(for: record)
            return ProgressPersonalRecord(
                id: record.id.uuidString,
                exerciseName: record.exerciseName,
                weightKg: weightKg,
                reps: reps,
                weeklyChangeKg: nil,
                isNewPRThisWeek: isNewThisWeek,
                valueLabel: valueLabel
            )
        }
    }

    private static func displayValues(for record: PersonalRecord) -> (Double, Int, String) {
        switch record.recordType {
        case .maxWeight:
            let label = String(format: "%.0f kg 1RM", record.value)
            return (record.value, 1, label)
        case .maxReps:
            let label = "\(Int(record.value)) reps"
            return (0, Int(record.value), label)
        case .maxVolume:
            let label = String(format: "%.0f kg·reps", record.value)
            return (record.value, 1, label)
        case .fastestPace:
            let label = String(format: "%.1f min/km", record.value)
            return (record.value, 1, label)
        case .longestDistance:
            let label = String(format: "%.1f km", record.value)
            return (record.value, 1, label)
        }
    }

    static func personalRecords(from sets: [ExerciseSet]) -> [ProgressPersonalRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        guard let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) else { return [] }

        var bestByExercise: [String: ExerciseSet] = [:]
        for set in sets {
            guard let reps = set.reps, let weightKg = set.weightKg else { continue }
            if let existing = bestByExercise[set.exerciseName] {
                let existingVolume = (existing.weightKg ?? 0) * Double(existing.reps ?? 0)
                if weightKg * Double(reps) > existingVolume {
                    bestByExercise[set.exerciseName] = set
                }
            } else {
                bestByExercise[set.exerciseName] = set
            }
        }

        var prevBestByExercise: [String: Double] = [:]
        for set in sets where set.completedAt < weekStart && set.completedAt >= prevWeekStart {
            guard let reps = set.reps, let weightKg = set.weightKg else { continue }
            let volume = weightKg * Double(reps)
            prevBestByExercise[set.exerciseName] = max(prevBestByExercise[set.exerciseName] ?? 0, volume)
        }

        return bestByExercise.values
            .sorted {
                let lhs = ($0.weightKg ?? 0) * Double($0.reps ?? 0)
                let rhs = ($1.weightKg ?? 0) * Double($1.reps ?? 0)
                return lhs > rhs
            }
            .prefix(3)
            .compactMap { set in
                guard let reps = set.reps, let weightKg = set.weightKg else { return nil }
                let currentVolume = weightKg * Double(reps)
                let prevVolume = prevBestByExercise[set.exerciseName]
                let isNewThisWeek = set.completedAt >= weekStart
                let change: Double?
                if let prevVolume, prevVolume > 0 {
                    let prevWeight = prevVolume / Double(max(reps, 1))
                    change = weightKg - prevWeight
                } else if isNewThisWeek {
                    change = nil
                } else {
                    change = 0
                }

                return ProgressPersonalRecord(
                    id: set.exerciseName,
                    exerciseName: set.exerciseName,
                    weightKg: weightKg,
                    reps: reps,
                    weeklyChangeKg: change,
                    isNewPRThisWeek: isNewThisWeek && (change == nil || (change ?? 0) > 0)
                )
            }
    }

    static func habitHeatmap(
        habits: [Habit],
        completions: [HabitCompletion],
        weeks: Int,
        calendar: Calendar = .current
    ) -> [HabitHeatmapCell] {
        guard !habits.isEmpty else { return [] }

        let today = calendar.startOfDay(for: .now)
        let activeHabitCount = habits.filter(\.isActive).count
        guard activeHabitCount > 0 else { return [] }

        let totalDays = weeks * 7
        guard let start = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) else { return [] }

        return (0..<totalDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

            let completedCount = habits.filter { habit in
                completions.contains { completion in
                    completion.habitId == habit.id
                        && completion.completedDate >= dayStart
                        && completion.completedDate < dayEnd
                }
            }.count

            let rate = Double(completedCount) / Double(activeHabitCount)
            let daysFromStart = offset
            let weekIndex = daysFromStart / 7

            return HabitHeatmapCell(
                id: dayStart,
                date: dayStart,
                completionRate: rate,
                weekIndex: weekIndex
            )
        }
    }

    static func waterWeekDays(
        logs: [WaterLog],
        goalMl: Int,
        calendar: Calendar = .current
    ) -> [WaterWeekDay] {
        let today = calendar.startOfDay(for: .now)
        let weekStart = mondayStart(for: today, calendar: calendar)
        let labels = ["M", "T", "W", "T", "F", "S", "S"]

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? today
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let amount = logs
                .filter { $0.loggedAt >= dayStart && $0.loggedAt < dayEnd }
                .reduce(0) { $0 + $1.amountMl }

            return WaterWeekDay(id: offset, label: labels[offset], amountMl: amount, goalMl: goalMl)
        }
    }

    static func mondayStart(for date: Date, calendar: Calendar) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: date)) ?? date
    }
}
