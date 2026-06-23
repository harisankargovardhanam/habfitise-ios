import Foundation

struct SessionExercise: Identifiable, Equatable {
    let id: UUID
    let name: String
    let totalSets: Int
    var setsCompleted: Int
    let targetReps: Int
    let targetWeightKg: Double
    var loggedVolumeKg: Double = 0
    var maxLoggedWeightKg: Double = 0

    var setProgress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(setsCompleted) / Double(totalSets)
    }

    var volumeKg: Double {
        loggedVolumeKg
    }
}

struct CompletedSetSnapshot: Identifiable, Equatable {
    let id = UUID()
    let exerciseName: String
    let setNumber: Int
    let reps: Int
    let weightKg: Double
}

struct WorkoutCompletionStats: Equatable {
    let durationSeconds: Int
    let totalSets: Int
    let totalVolumeKg: Double
    let newPRs: [WorkoutPersonalRecord]
}

struct WorkoutCompletePR: Identifiable, Equatable {
    let id: UUID
    let exerciseName: String
    let newValue: String
    let previousValue: String?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        newValue: String,
        previousValue: String? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.newValue = newValue
        self.previousValue = previousValue
    }
}

extension Array where Element == WorkoutCompletePR {
    /// Keeps the first PR per exercise — avoids duplicate cards on session complete.
    func dedupedByExercise() -> [WorkoutCompletePR] {
        var seen = Set<String>()
        return filter { seen.insert($0.exerciseName).inserted }
    }
}

struct WorkoutCompletePayload: Equatable {
    let workoutName: String
    let workoutType: WorkoutType
    let completedAt: Date
    let durationSeconds: Int
    let totalVolumeKg: Double
    let totalSets: Int
    let sessionNotes: String
    let newPRs: [WorkoutCompletePR]
    let estimatedCalories: Int

    init(
        workoutName: String,
        workoutType: WorkoutType,
        completedAt: Date = .now,
        durationSeconds: Int,
        totalVolumeKg: Double,
        totalSets: Int,
        sessionNotes: String,
        newPRs: [WorkoutCompletePR],
        estimatedCalories: Int = 0
    ) {
        self.workoutName = workoutName
        self.workoutType = workoutType
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.totalVolumeKg = totalVolumeKg
        self.totalSets = totalSets
        self.sessionNotes = sessionNotes
        self.newPRs = newPRs
        self.estimatedCalories = estimatedCalories
    }

    init(stats: WorkoutCompletionStats, workoutName: String, workoutType: WorkoutType = .weights, sessionNotes: String = "", estimatedCalories: Int = 0) {
        self.workoutName = workoutName
        self.workoutType = workoutType
        self.completedAt = .now
        self.durationSeconds = stats.durationSeconds
        self.totalVolumeKg = stats.totalVolumeKg
        self.totalSets = stats.totalSets
        self.sessionNotes = sessionNotes
        self.newPRs = stats.newPRs.map {
            WorkoutCompletePR(exerciseName: $0.exerciseName, newValue: $0.detail)
        }
        self.estimatedCalories = estimatedCalories
    }
}

struct WorkoutCompleteResult: Equatable {
    let perceivedExertion: Int
    let notes: String
    let scheduleRepeat: Bool
    let repeatSchedule: RepeatSchedule?
    let customRepeatDate: Date?
}

struct WorkoutPersonalRecord: Identifiable, Equatable {
    let id = UUID()
    let exerciseName: String
    let detail: String
}

enum ActiveWorkoutPhase: Equatable {
    case idle
    case active(exerciseIndex: Int, setIndex: Int)
    case resting(secondsRemaining: Int)
    case complete
}

enum ChartTimeRange: String, CaseIterable, Identifiable {
    case day
    case week

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: "D"
        case .week: "W"
        }
    }
}

enum ActiveWorkoutInputField: Equatable {
    case reps
    case weight
}

enum ActiveWorkoutFactory {
    static func exercises(for type: WorkoutType, workoutName: String) -> [SessionExercise] {
        switch type {
        case .cardio:
            return [makeExercise(name: "Cardio", sets: 1, reps: 1, weight: 0)]
        case .bodyweight:
            return [
                makeExercise(name: "Push-ups", sets: 3, reps: 15, weight: 0),
                makeExercise(name: "Squats", sets: 3, reps: 20, weight: 0),
                makeExercise(name: "Plank", sets: 3, reps: 1, weight: 0)
            ]
        case .hiit:
            return [
                makeExercise(name: "Burpees", sets: 4, reps: 12, weight: 0),
                makeExercise(name: "Mountain Climbers", sets: 4, reps: 20, weight: 0),
                makeExercise(name: "Jump Squats", sets: 4, reps: 15, weight: 0)
            ]
        case .flexibility:
            return [
                makeExercise(name: "Stretch Flow", sets: 1, reps: 1, weight: 0)
            ]
        case .weights:
            return defaultExercises(for: workoutName)
        }
    }

    static func exercises(from template: WorkoutTemplate) -> [SessionExercise] {
        let ordered = template.exercises.sorted { $0.order < $1.order }
        guard !ordered.isEmpty else {
            return exercises(for: template.type, workoutName: template.name)
        }
        return ordered.map { exercise in
            makeExercise(
                name: exercise.name,
                sets: exercise.defaultSets,
                reps: exercise.defaultReps,
                weight: exercise.defaultWeightKg
            )
        }
    }

    static func defaultExercises(for workoutName: String) -> [SessionExercise] {
        let rows: [(String, Int, Int, Double)]
        switch workoutName.lowercased() {
        case let name where name.contains("push") || name.contains("chest") || name.contains("upper"):
            rows = [
                ("Bench Press", 4, 10, 60),
                ("Incline DB Press", 3, 12, 22),
                ("Cable Fly", 3, 15, 15),
                ("Tricep Pushdown", 3, 12, 25)
            ]
        default:
            rows = [
                ("Barbell Squat", 4, 8, 80),
                ("Romanian Deadlift", 3, 10, 70),
                ("Leg Press", 3, 12, 120),
                ("Calf Raise", 3, 15, 40)
            ]
        }

        return rows.map { name, sets, reps, weight in
            makeExercise(name: name, sets: sets, reps: reps, weight: weight)
        }
    }

    private static func makeExercise(name: String, sets: Int, reps: Int, weight: Double) -> SessionExercise {
        SessionExercise(
            id: UUID(),
            name: name,
            totalSets: sets,
            setsCompleted: 0,
            targetReps: reps,
            targetWeightKg: weight
        )
    }
}
