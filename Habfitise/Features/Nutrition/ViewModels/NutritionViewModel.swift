import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class NutritionViewModel {
    var inputMode: FoodLogInputMode = .foodName
    var portionSize: NutritionPortionSize = .regular
    var foodName = ""
    var ingredientRows: [NutritionIngredientDraft] = [
        NutritionIngredientDraft(name: "", amount: 1, unit: NutritionIngredientUnit.cup.label)
    ]

    var isEstimating = false
    var estimateError: String?
    var pendingEstimate: NutritionEstimateDraft?

    private static var estimateCache: [String: NutritionEstimateDraft] = [:]

    private(set) var daySummary = NutritionDaySummary.empty

    func refresh(logs: [FoodLog], profile: UserProfile?, activeEnergyKcal: Int = 0) {
        daySummary = NutritionCalculator.daySummary(
            logs: logs,
            profile: profile,
            activeEnergyKcal: activeEnergyKcal
        )
    }

    func resetDraft() {
        foodName = ""
        portionSize = .regular
        ingredientRows = [NutritionIngredientDraft(name: "", amount: 1, unit: NutritionIngredientUnit.cup.label)]
        estimateError = nil
        pendingEstimate = nil
        isEstimating = false
    }

    func addIngredientRow() {
        ingredientRows.append(NutritionIngredientDraft())
    }

    func removeIngredientRow(_ id: UUID) {
        guard ingredientRows.count > 1 else { return }
        ingredientRows.removeAll { $0.id == id }
    }

    func estimateWithAI(appState: AppState) async {
        guard appState.isPro else {
            appState.requireUpgrade(for: .aiNutrition)
            return
        }

        estimateError = nil
        pendingEstimate = nil

        guard validateInput() else { return }

        isEstimating = true
        defer { isEstimating = false }

        do {
            let request = buildRequest()
            let cacheKey = Self.cacheKey(for: request)
            if let cached = Self.estimateCache[cacheKey] {
                pendingEstimate = cached
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                return
            }

            let response = try await EdgeFunctionService.shared.estimateNutrition(request)
            let draft = NutritionEstimateDraft(
                title: displayTitle,
                calories: .init(
                    low: response.caloriesKcal.low,
                    mid: response.caloriesKcal.mid,
                    high: response.caloriesKcal.high
                ),
                protein: .init(
                    low: response.proteinG.low,
                    mid: response.proteinG.mid,
                    high: response.proteinG.high
                ),
                confidence: response.confidence,
                assumptions: response.assumptions
            )
            Self.estimateCache[cacheKey] = draft
            pendingEstimate = draft
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch EdgeFunctionServiceError.proRequired {
            appState.requireUpgrade(for: .aiNutrition)
        } catch {
            estimateError = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func saveEstimate(userId: String, context: ModelContext) {
        guard let estimate = pendingEstimate else { return }

        let log = FoodLog(
            userId: userId,
            title: estimate.title,
            mode: inputMode.apiMode,
            caloriesLow: estimate.calories.low,
            caloriesMid: estimate.calories.mid,
            caloriesHigh: estimate.calories.high,
            proteinLow: estimate.protein.low,
            proteinMid: estimate.protein.mid,
            proteinHigh: estimate.protein.high,
            confidence: estimate.confidence,
            assumptionsJSON: encodeAssumptions(estimate.assumptions),
            ingredientsJSON: inputMode == .ingredients ? encodeIngredients() : nil
        )
        context.insert(log)
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        resetDraft()
    }

    func deleteLog(_ log: FoodLog, context: ModelContext) {
        context.delete(log)
        try? context.save()
    }

    // MARK: - Private

    private var displayTitle: String {
        if inputMode == .foodName {
            return foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let names = ingredientRows
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if names.count <= 2 {
            return names.joined(separator: " + ")
        }
        return "\(names.prefix(2).joined(separator: ", ")) + \(names.count - 2) more"
    }

    private func validateInput() -> Bool {
        switch inputMode {
        case .foodName:
            let trimmed = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                estimateError = "Describe what you ate."
                return false
            }
            return true
        case .ingredients:
            let valid = ingredientRows.contains {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.amount > 0
            }
            if !valid {
                estimateError = "Add at least one ingredient with an amount."
                return false
            }
            return true
        }
    }

    private func buildRequest() -> NutritionEstimateRequest {
        switch inputMode {
        case .foodName:
            return NutritionEstimateRequest(
                mode: FoodLogInputMode.foodName.apiMode,
                text: foodName.trimmingCharacters(in: .whitespacesAndNewlines),
                ingredients: nil,
                portionHint: portionSize.apiHint
            )
        case .ingredients:
            let items = ingredientRows.compactMap { row -> NutritionEstimateRequest.NutritionIngredient? in
                let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, row.amount > 0 else { return nil }
                return .init(name: name, amount: row.amount, unit: row.unit)
            }
            return NutritionEstimateRequest(
                mode: FoodLogInputMode.ingredients.apiMode,
                text: nil,
                ingredients: items,
                portionHint: nil
            )
        }
    }

    private func encodeAssumptions(_ assumptions: [String]) -> String {
        guard let data = try? JSONEncoder().encode(assumptions),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func encodeIngredients() -> String {
        let payload = ingredientRows.compactMap { row -> [String: Any]? in
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return ["name": name, "amount": row.amount, "unit": row.unit]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func cacheKey(for request: NutritionEstimateRequest) -> String {
        if request.mode == FoodLogInputMode.ingredients.apiMode,
           let ingredients = request.ingredients {
            let parts = ingredients
                .map { "\($0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\($0.amount)|\($0.unit.lowercased())" }
                .sorted()
            return "ingredients:" + parts.joined(separator: ";")
        }

        let text = (request.text ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let portion = (request.portionHint ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "food:\(text)|\(portion)"
    }
}
