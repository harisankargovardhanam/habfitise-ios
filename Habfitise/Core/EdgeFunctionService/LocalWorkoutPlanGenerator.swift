import Foundation

enum LocalWorkoutPlanGenerator {
    static func makeResponse(for request: WorkoutPlanRequest) -> WorkoutPlanResponse {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let workoutName: String
        let muscleGroups: String
        let exercises: [[String: Any]]

        switch request.goal {
        case "lose_weight":
            workoutName = "Fat Loss Circuit"
            muscleGroups = "Full Body · Cardio"
            exercises = [
                ["name": "Treadmill intervals", "sets": 4],
                ["name": "Goblet squat", "sets": 3],
                ["name": "Push-ups", "sets": 3],
                ["name": "Row machine", "sets": 3]
            ]
        case "build_muscle":
            workoutName = "Upper Body Push"
            muscleGroups = "Chest · Shoulders · Triceps"
            exercises = [
                ["name": "Bench press", "sets": 4],
                ["name": "Incline DB press", "sets": 3],
                ["name": "Cable fly", "sets": 3],
                ["name": "Tricep pushdown", "sets": 3]
            ]
        default:
            workoutName = "Full Body Strength"
            muscleGroups = "Full Body"
            exercises = [
                ["name": "Barbell squat", "sets": 4],
                ["name": "Romanian deadlift", "sets": 3],
                ["name": "Overhead press", "sets": 3],
                ["name": "Plank", "sets": 3]
            ]
        }

        let plan: [String: Any] = [
            "name": workoutName,
            "title": workoutName,
            "durationMinutes": 45,
            "muscleGroups": muscleGroups,
            "focus": muscleGroups,
            "exerciseCount": exercises.count,
            "exercises": exercises,
            "goal": request.goal,
            "trainingDays": request.trainingDays,
            "equipment": request.equipment,
            "generatedLocally": true
        ]

        let planData = (try? JSONSerialization.data(withJSONObject: plan)) ?? Data()
        let planJSON = String(data: planData, encoding: .utf8) ?? "{}"

        return WorkoutPlanResponse(
            planId: UUID().uuidString,
            plan: planJSON,
            generatedAt: formatter.string(from: .now)
        )
    }
}
