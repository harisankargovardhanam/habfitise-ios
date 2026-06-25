import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class NutritionViewModel {
    var inputMode: FoodLogInputMode = .foodName
    var foodName = ""
    var ingredientRows: [NutritionIngredientDraft] = [
        NutritionIngredientDraft(name: "", amount: 1, unit: NutritionIngredientUnit.cup.label)
    ]

    var isEstimating = false
    var estimateError: String?
    var pendingEstimate: NutritionEstimateDraft?

    private static var estimateCache: [String: NutritionEstimateDraft] = [:]

    private(set) var daySummary = NutritionDaySummary.empty
    private var userTimezone: String?
    private var userLocale: String?

    var showsMilkTeaDefaultHint: Bool {
        let text = foodName.lowercased()
        guard inputMode == .foodName, text.contains("tea") || text.contains("chai") else { return false }
        guard !text.contains("black") && !text.contains("without milk") && !text.contains("no milk") else {
            return false
        }
        return Self.isSouthAsiaRegion(timezone: userTimezone, locale: userLocale)
    }

    func refresh(logs: [FoodLog], profile: UserProfile?, activeEnergyKcal: Int = 0) {
        userTimezone = profile?.timezone
        userLocale = Locale.current.identifier
        daySummary = NutritionCalculator.daySummary(
            logs: logs,
            profile: profile,
            activeEnergyKcal: activeEnergyKcal
        )
    }

    func resetDraft() {
        foodName = ""
        ingredientRows = [NutritionIngredientDraft(name: "", amount: 1, unit: NutritionIngredientUnit.cup.label)]
        estimateError = nil
        pendingEstimate = nil
        isEstimating = false
        Self.estimateCache.removeAll()
    }

    func clearPendingLookup() {
        let cacheKey = Self.cacheKey(for: buildRequest())
        Self.estimateCache.removeValue(forKey: cacheKey)
        pendingEstimate = nil
        estimateError = nil
    }

    func addIngredientRow() {
        ingredientRows.append(NutritionIngredientDraft())
    }

    func removeIngredientRow(_ id: UUID) {
        guard ingredientRows.count > 1 else { return }
        ingredientRows.removeAll { $0.id == id }
    }

    func resolveNutrition(appState: AppState) async {
        if inputMode == .ingredients && !appState.isPro {
            appState.requireUpgrade(for: .aiNutrition)
            return
        }

        estimateError = nil
        pendingEstimate = nil

        guard validateInput() else { return }

        isEstimating = true
        defer { isEstimating = false }

        let request = buildRequest()
        let cacheKey = Self.cacheKey(for: request)
        let region = Self.regionBucket(timezone: userTimezone, locale: userLocale)

        if inputMode == .foodName {
            if let meal = FoodCatalogLocal.matchMeal(query: foodName, region: region) {
                let draft = Self.draftFromLocalMeal(meal, title: displayTitle)
                Self.estimateCache[cacheKey] = draft
                pendingEstimate = draft
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                return
            }

            if let local = FoodCatalogLocal.match(query: foodName, region: region) {
                let draft = Self.draftFromLocalCatalog(local, title: displayTitle)
                Self.estimateCache[cacheKey] = draft
                pendingEstimate = draft
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                return
            }
        }

        if let cached = Self.estimateCache[cacheKey] {
            pendingEstimate = cached
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }

        do {
            let response = try await EdgeFunctionService.shared.estimateNutrition(request)
            let draft = Self.draft(from: response, title: displayTitle)
            Self.estimateCache[cacheKey] = draft
            pendingEstimate = draft
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch EdgeFunctionServiceError.proRequired {
            estimateError = "Not in our food database yet. VAYA Pro unlocks AI estimates."
            appState.requireUpgrade(for: .aiNutrition)
        } catch {
            estimateError = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// Backward-compatible entry point for existing call sites.
    func estimateWithAI(appState: AppState) async {
        await resolveNutrition(appState: appState)
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
            ingredientsJSON: inputMode == .ingredients ? encodeIngredients() : nil,
            estimateSource: estimate.source.rawValue,
            catalogFoodId: estimate.catalogFoodId
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
                portionHint: nil,
                timezone: userTimezone ?? TimeZone.current.identifier,
                locale: userLocale ?? Locale.current.identifier
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
                portionHint: nil,
                timezone: userTimezone ?? TimeZone.current.identifier,
                locale: userLocale ?? Locale.current.identifier
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
            return "ingredients:" + parts.joined(separator: ";") + "|\(Self.regionBucket(timezone: request.timezone, locale: request.locale))"
        }

        let text = (request.text ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let region = Self.regionBucket(
            timezone: request.timezone,
            locale: request.locale
        )
        return "food:v3:\(text)|\(region)"
    }

    private static func isSouthAsiaRegion(timezone: String?, locale: String?) -> Bool {
        regionBucket(timezone: timezone, locale: locale) == "south_asia"
    }

    private static func regionBucket(timezone: String?, locale: String?) -> String {
        let southAsiaTimezones: Set<String> = [
            "Asia/Kolkata", "Asia/Colombo", "Asia/Karachi", "Asia/Dhaka",
            "Asia/Kathmandu", "Asia/Thimphu", "Indian/Maldives"
        ]
        if let timezone, southAsiaTimezones.contains(timezone) {
            return "south_asia"
        }

        let localeValue = (locale ?? Locale.current.identifier).lowercased()
        let southAsiaCodes = ["in", "pk", "bd", "lk", "np", "mv"]
        if southAsiaCodes.contains(where: { code in
            localeValue == code ||
            localeValue.hasPrefix("\(code)_") ||
            localeValue.hasSuffix("_\(code)")
        }) {
            return "south_asia"
        }

        return "default"
    }

    private static func draft(from response: NutritionEstimateResponse, title: String) -> NutritionEstimateDraft {
        NutritionEstimateDraft(
            title: title,
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
            assumptions: response.assumptions,
            source: response.estimateSource,
            sourceLabel: response.sourceLabel,
            matchedName: response.matchedName,
            servingDescription: response.servingDescription,
            catalogFoodId: response.catalogFoodId
        )
    }

    private static func draftFromLocalCatalog(_ entry: FoodCatalogEntry, title: String) -> NutritionEstimateDraft {
        NutritionEstimateDraft(
            title: title,
            calories: .init(low: entry.caloriesLow, mid: entry.caloriesMid, high: entry.caloriesHigh),
            protein: .init(low: entry.proteinLow, mid: entry.proteinMid, high: entry.proteinHigh),
            confidence: "high",
            assumptions: [
                "Matched: \(entry.name)",
                "Serving: \(entry.servingDescription)",
                "On-device food database",
            ],
            source: .catalog,
            sourceLabel: "Verified food database",
            matchedName: entry.name,
            servingDescription: entry.servingDescription,
            catalogFoodId: nil
        )
    }

    private static func draftFromLocalMeal(_ entries: [FoodCatalogEntry], title: String) -> NutritionEstimateDraft {
        let calories = NutritionMacroRange(
            low: entries.reduce(0) { $0 + $1.caloriesLow },
            mid: entries.reduce(0) { $0 + $1.caloriesMid },
            high: entries.reduce(0) { $0 + $1.caloriesHigh }
        )
        let protein = NutritionMacroRange(
            low: entries.reduce(0) { $0 + $1.proteinLow },
            mid: entries.reduce(0) { $0 + $1.proteinMid },
            high: entries.reduce(0) { $0 + $1.proteinHigh }
        )

        let matchedName = entries.map(\.name).joined(separator: " + ")
        let servingDescription = entries.map(\.servingDescription).joined(separator: "; ")
        let assumptions = ["Meal: \(title)"] + entries.map {
            "Matched: \($0.name) — \($0.servingDescription)"
        } + ["On-device food database"]

        return NutritionEstimateDraft(
            title: title,
            calories: calories,
            protein: protein,
            confidence: "high",
            assumptions: assumptions,
            source: .catalog,
            sourceLabel: "Verified food database",
            matchedName: matchedName,
            servingDescription: servingDescription,
            catalogFoodId: nil
        )
    }
}
