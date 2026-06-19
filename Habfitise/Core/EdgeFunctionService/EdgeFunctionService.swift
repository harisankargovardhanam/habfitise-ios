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

@MainActor
final class EdgeFunctionService {
    static let shared = EdgeFunctionService()

    private init() {}

    func generateWorkoutPlan(_ request: WorkoutPlanRequest) async throws -> WorkoutPlanResponse {
        if AppConstants.Backend.useLocalOnly {
            return LocalWorkoutPlanGenerator.makeResponse(for: request)
        }

        guard let client = SupabaseManager.shared.client else {
            throw EdgeFunctionServiceError.notConfigured
        }

        return try await client.functions.invoke(
            AppConstants.EdgeFunctions.planGenerator,
            options: FunctionInvokeOptions(body: request)
        )
    }

    func generateDailyPlan(_ request: DailyPlanRequest) async throws -> DailyPlanResponse {
        if AppConstants.Backend.useLocalOnly {
            throw EdgeFunctionServiceError.notConfigured
        }

        guard let client = SupabaseManager.shared.client else {
            throw EdgeFunctionServiceError.notConfigured
        }

        return try await client.functions.invoke(
            AppConstants.EdgeFunctions.planGenerator,
            options: FunctionInvokeOptions(body: request)
        )
    }

    func reschedulePlan(_ request: RescheduleRequest) async throws -> RescheduleResponse {
        if AppConstants.Backend.useLocalOnly {
            throw EdgeFunctionServiceError.notConfigured
        }

        guard let client = SupabaseManager.shared.client else {
            throw EdgeFunctionServiceError.notConfigured
        }

        return try await client.functions.invoke(
            AppConstants.EdgeFunctions.reschedule,
            options: FunctionInvokeOptions(body: request)
        )
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
