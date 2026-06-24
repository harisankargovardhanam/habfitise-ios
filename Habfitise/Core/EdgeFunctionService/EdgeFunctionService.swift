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
    let context: [String: String]?

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

struct NutritionEstimateRequest: Encodable {
    let mode: String
    let text: String?
    let ingredients: [NutritionIngredient]?
    let portionHint: String?

    struct NutritionIngredient: Encodable {
        let name: String
        let amount: Double
        let unit: String
    }
}

struct NutritionEstimateResponse: Decodable {
    let caloriesKcal: NutritionRange
    let proteinG: NutritionRange
    let confidence: String
    let assumptions: [String]
    let disclaimer: String

    struct NutritionRange: Decodable {
        let low: Int
        let mid: Int
        let high: Int
    }
}

/// Calls Supabase Edge Functions when configured; falls back to on-device generators.
@MainActor
final class EdgeFunctionService {
    static let shared = EdgeFunctionService()

    private init() {}

    func generateWorkoutPlan(_ request: WorkoutPlanRequest) async throws -> WorkoutPlanResponse {
        try await invoke(
            AppConstants.EdgeFunctions.planGenerator,
            body: request,
            fallback: { LocalWorkoutPlanGenerator.makeResponse(for: request) }
        )
    }

    func generateDailyPlan(_ request: DailyPlanRequest) async throws -> DailyPlanResponse {
        try await invoke(
            AppConstants.EdgeFunctions.dailyPlan,
            body: request,
            fallback: { self.makeLocalDailyPlanResponse(for: request) }
        )
    }

    func reschedulePlan(_ request: RescheduleRequest) async throws -> RescheduleResponse {
        try await invoke(
            AppConstants.EdgeFunctions.reschedule,
            body: request,
            fallback: { RescheduleResponse(updatedPlan: request.currentPlan) }
        )
    }

    func estimateNutrition(_ request: NutritionEstimateRequest) async throws -> NutritionEstimateResponse {
        try await invoke(
            AppConstants.EdgeFunctions.nutritionEstimate,
            body: request,
            fallback: nil
        )
    }

    // MARK: - Private

    private func invoke<Response: Decodable, Body: Encodable>(
        _ name: String,
        body: Body,
        fallback: (() -> Response)?
    ) async throws -> Response {
        if AppConstants.Backend.useLocalOnly {
            guard let fallback else { throw EdgeFunctionServiceError.notConfigured }
            return fallback()
        }

        guard let client = SupabaseManager.shared.client else {
            guard let fallback else { throw EdgeFunctionServiceError.notConfigured }
            return fallback()
        }

        _ = await SupabaseManager.shared.currentSession()

        do {
            return try await client.functions.invoke(
                name,
                options: FunctionInvokeOptions(body: body)
            )
        } catch {
            if let fallback, shouldFallbackToLocal(error) {
                return fallback()
            }
            throw mapInvokeError(error)
        }
    }

    private func shouldFallbackToLocal(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        if description.contains("404") || description.contains("not found") {
            return true
        }
        if description.contains("could not connect") || description.contains("network") {
            return true
        }
        return false
    }

    private func mapInvokeError(_ error: Error) -> Error {
        let description = String(describing: error).lowercased()
        if description.contains("402") || description.contains("subscription required") {
            return EdgeFunctionServiceError.proRequired
        }
        if description.contains("401") || description.contains("unauthorized") {
            return EdgeFunctionServiceError.unauthorized
        }
        return error
    }

    private func makeLocalDailyPlanResponse(for request: DailyPlanRequest) -> DailyPlanResponse {
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
}

enum EdgeFunctionServiceError: LocalizedError {
    case notConfigured
    case unauthorized
    case proRequired

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase client must be configured before calling edge functions."
        case .unauthorized:
            "Sign in again to use cloud features."
        case .proRequired:
            "VAYA Pro subscription required."
        }
    }
}
