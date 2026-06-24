import Foundation

struct ParsedTodayWorkout {
    let name: String
    let exerciseCount: Int
    let durationMinutes: Int
    let muscleGroups: String

    static let placeholder = ParsedTodayWorkout(
        name: "Upper Body Push",
        exerciseCount: 4,
        durationMinutes: 45,
        muscleGroups: "Chest · Shoulders"
    )

    var chipLabels: [String] {
        [
            "\(exerciseCount) exercises",
            "~\(durationMinutes) min",
            muscleGroups
        ]
    }
}

struct HomeHabitChipItem: Identifiable {
    let id: UUID
    let name: String
    let isCompleted: Bool
}

struct HomeTaskItem: Identifiable {
    let id: UUID
    let title: String
    let isComplete: Bool
}

struct HomeStreakStats {
    let weeklyCompleted: Int
    let weeklyTotal: Int
    let dayStreak: Int
    let sessionsLogged: Int
    let habitsDone: Int
}

enum HomeTodayWorkoutMode: Equatable {
    case completed
    case scheduled
    case quickStart
}

struct HomeWorkoutCardModel: Equatable {
    let mode: HomeTodayWorkoutMode
    let title: String
    let chips: [String]
    let templateId: UUID?
    let workoutType: WorkoutType?
    let sessionId: UUID?
    let summaryDuration: String?
    let summaryVolume: String?
    let suggestedType: WorkoutType?
    let suggestionReason: String?

    static let quickStart = HomeWorkoutCardModel(
        mode: .quickStart,
        title: "Quick Start",
        chips: ["Pick a workout type below"],
        templateId: nil,
        workoutType: nil,
        sessionId: nil,
        summaryDuration: nil,
        summaryVolume: nil,
        suggestedType: nil,
        suggestionReason: nil
    )
}

struct PendingWorkoutBuilder: Equatable {
    let workoutType: WorkoutType
    let templateId: UUID?
}

enum HomeWorkoutPlanParser {
    static func parse(planJSON: String) -> ParsedTodayWorkout {
        guard
            let data = planJSON.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .placeholder
        }

        let name = json["name"] as? String ?? json["title"] as? String ?? ParsedTodayWorkout.placeholder.name
        let exercises = json["exercises"] as? [[String: Any]] ?? []
        let exerciseCount = exercises.count > 0 ? exercises.count : (json["exerciseCount"] as? Int ?? 4)
        let duration = json["durationMinutes"] as? Int ?? json["duration_minutes"] as? Int ?? 45
        let groups = json["muscleGroups"] as? String
            ?? json["focus"] as? String
            ?? ParsedTodayWorkout.placeholder.muscleGroups

        return ParsedTodayWorkout(
            name: name,
            exerciseCount: exerciseCount,
            durationMinutes: duration,
            muscleGroups: groups
        )
    }
}
