import Foundation

enum NutritionPortionSize: String, CaseIterable, Identifiable {
    case small
    case regular
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .regular: "Regular"
        case .large: "Large"
        }
    }

    var subtitle: String {
        switch self {
        case .small: "~half plate"
        case .regular: "~1 plate"
        case .large: "~1.5× plate"
        }
    }

    /// Sent to the nutrition edge function as `portionHint`.
    var apiHint: String {
        switch self {
        case .small:
            "Small portion (~175g cooked, or half a restaurant plate)"
        case .regular:
            "Regular portion (~350g cooked, or 1 standard restaurant plate)"
        case .large:
            "Large portion (~525g cooked, or 1.5× restaurant plate)"
        }
    }
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
