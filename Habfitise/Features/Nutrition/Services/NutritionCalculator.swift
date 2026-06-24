import Foundation

enum NutritionCalculator {
    /// Rough maintenance from weight; adjusted by onboarding goal.
    static func dailyCalorieTarget(profile: UserProfile?, activeEnergyKcal: Int = 0) -> Int {
        let weight = max(profile?.weightKg ?? 70, 40)
        var maintenance = Int((weight * 24).rounded())

        switch profile?.goal {
        case "lose_weight":
            maintenance -= 400
        case "build_muscle":
            maintenance += 250
        default:
            break
        }

        maintenance += min(activeEnergyKcal / 2, 350)
        return max(maintenance, 1_400)
    }

    static func dailyProteinTarget(profile: UserProfile?) -> Int {
        let weight = max(profile?.weightKg ?? 70, 40)
        let gramsPerKg: Double = profile?.goal == "build_muscle" ? 1.8 : 1.4
        return max(Int((weight * gramsPerKg).rounded()), 60)
    }

    static func daySummary(
        logs: [FoodLog],
        profile: UserProfile?,
        activeEnergyKcal: Int = 0
    ) -> NutritionDaySummary {
        let calorieTarget = dailyCalorieTarget(profile: profile, activeEnergyKcal: activeEnergyKcal)
        let proteinTarget = dailyProteinTarget(profile: profile)

        let consumedCalories = logs.reduce(0) { $0 + $1.caloriesMid }
        let consumedProtein = logs.reduce(0) { $0 + $1.proteinMid }
        let remaining = calorieTarget - consumedCalories
        let isOver = remaining < 0

        let balanceLabel: String
        if logs.isEmpty {
            balanceLabel = "Log your first meal"
        } else if isOver {
            balanceLabel = "\(abs(remaining)) kcal over goal"
        } else if remaining <= 150 {
            balanceLabel = "On track today"
        } else {
            balanceLabel = "\(remaining) kcal remaining"
        }

        return NutritionDaySummary(
            consumedCalories: consumedCalories,
            consumedProtein: consumedProtein,
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            remainingCalories: remaining,
            mealCount: logs.count,
            balanceLabel: balanceLabel,
            isOverTarget: isOver
        )
    }
}
