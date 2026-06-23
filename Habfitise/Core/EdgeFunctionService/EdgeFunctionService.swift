import Foundation
import Supabase

struct WorkoutPlanRequest: Encodable {
    let userId: String
    let goal: String
    let currentWeightKg: Double
    let targetWeightKg: Double
    let goalDeadline: String
    let timelineMonths: Int
    let trainingDays: [String]
    let preferredTime: String
    let equipment: String
    let dailyWaterGoalMl: Int
}

struct WorkoutPlanResponse: Decodable {
    let planId: String
    let plan: String
    let generatedAt: String
}

struct DailyPlanRequest: Encodable {
    let date: String
    let goals: [String]
    let schedulePreferences: SchedulePreferences

    struct SchedulePreferences: Encodable {
        let workoutDaysPerWeek: Int
        let preferredWorkoutTime: String?
    }
}

struct DailyPlanResponse: Decodable {
    let plan: String
    let generatedAt: String
}

struct RescheduleRequest: Encodable {
    let planID: String
    let reason: String
    let currentPlan: String
}

struct RescheduleResponse: Decodable {
    let updatedPlan: String
}

/// Workout plans are generated on-device. User data syncs to Supabase via `SyncService` — no Edge Functions required.
@MainActor
final class EdgeFunctionService {
    static let shared = EdgeFunctionService()

    private init() {}

    func generateWorkoutPlan(_ request: WorkoutPlanRequest) async throws -> WorkoutPlanResponse {
        LocalWorkoutPlanGenerator.makeResponse(for: request)
    }

    func generateDailyPlan(_ request: DailyPlanRequest) async throws -> DailyPlanResponse {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let plan: [String: Any] = [
            "title": "Today's focus",
            "date": request.date,
            "goals": request.goals,
            "generatedLocally": true
        ]
        let planJSON = String(
            data: (try? JSONSerialization.data(withJSONObject: plan)) ?? Data("{}".utf8),
            encoding: .utf8
        ) ?? "{}"

        return DailyPlanResponse(
            plan: planJSON,
            generatedAt: formatter.string(from: .now)
        )
    }

    func reschedulePlan(_ request: RescheduleRequest) async throws -> RescheduleResponse {
        RescheduleResponse(updatedPlan: request.currentPlan)
    }
}

enum EdgeFunctionServiceError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase client must be configured before calling edge functions."
        }
    }
}
