import Foundation

struct DailyActivitySummary: Equatable {
    let health: HomeHealthSnapshot
    let workoutMinutesToday: Int
    let workoutVolumeKg: Double
    let hasCompletedWorkoutToday: Bool
    let combinedExerciseMinutes: Int

    var stepProgress: Double { health.stepProgress }

    var exerciseProgress: Double {
        min(Double(combinedExerciseMinutes) / Double(AppConstants.Health.defaultExerciseGoalMinutes), 1)
    }

    var workoutProgress: Double {
        guard hasCompletedWorkoutToday else { return 0 }
        return min(Double(workoutMinutesToday) / 45.0, 1)
    }
}

struct SmartWorkoutSuggestion: Equatable {
    let type: WorkoutType
    let reason: String
}

struct DailyBrief: Equatable {
    let line: String
}

struct WellnessScore: Equatable {
    let score: Int
    let workoutPoints: Int
    let stepsPoints: Int
    let habitsPoints: Int
    let waterPoints: Int
}

struct TrainingTrendDay: Identifiable, Equatable {
    let id: String
    let label: String
    let workoutMinutes: Double
    let steps: Int
    let isToday: Bool
}

struct RecoveryContext: Equatable {
    let healthExerciseMinutes: Int
    let yesterdayVolumeKg: Double

    static let empty = RecoveryContext(healthExerciseMinutes: 0, yesterdayVolumeKg: 0)
}
