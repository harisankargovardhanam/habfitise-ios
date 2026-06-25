import Foundation

enum NutritionEstimateSource: String, Codable, Equatable {
    case catalog
    case usda
    case mixed
    case ai

    var displayLabel: String {
        switch self {
        case .catalog: "Food database"
        case .usda: "USDA FoodData"
        case .mixed: "Food database + AI"
        case .ai: "AI estimate"
        }
    }

    var isAI: Bool { self == .ai }

    var showsAICaution: Bool { self == .ai || self == .mixed }
}

enum FoodLogInputMode: String, CaseIterable, Identifiable {
    case foodName
    case ingredients

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foodName: "Describe meal"
        case .ingredients: "Ingredients"
        }
    }

    var apiMode: String {
        switch self {
        case .foodName: "food_name"
        case .ingredients: "ingredients"
        }
    }
}

struct NutritionIngredientDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var amount: Double
    var unit: String

    init(id: UUID = UUID(), name: String = "", amount: Double = 1, unit: String = "cup") {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
    }
}

enum NutritionIngredientUnit: String, CaseIterable, Identifiable {
    case gram
    case cup
    case tbsp
    case piece

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gram: "g"
        case .cup: "cup"
        case .tbsp: "tbsp"
        case .piece: "pc"
        }
    }
}

struct NutritionMacroRange: Equatable {
    let low: Int
    let mid: Int
    let high: Int
}

struct NutritionEstimateDraft: Equatable {
    let title: String
    let calories: NutritionMacroRange
    let protein: NutritionMacroRange
    let confidence: String
    let assumptions: [String]
    let source: NutritionEstimateSource
    let sourceLabel: String
    let matchedName: String
    let servingDescription: String
    let catalogFoodId: String?
}

struct NutritionDaySummary: Equatable {
    let consumedCalories: Int
    let consumedProtein: Int
    let calorieTarget: Int
    let proteinTarget: Int
    let remainingCalories: Int
    let mealCount: Int
    let balanceLabel: String
    let isOverTarget: Bool

    static let empty = NutritionDaySummary(
        consumedCalories: 0,
        consumedProtein: 0,
        calorieTarget: 2_000,
        proteinTarget: 120,
        remainingCalories: 2_000,
        mealCount: 0,
        balanceLabel: "Log your first meal",
        isOverTarget: false
    )
}
