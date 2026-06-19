import Foundation
import Observation

@Observable
@MainActor
final class WaterViewModel {
    var totalML = 0
    var goalML = AppConstants.Water.defaultDailyGoalML
    var weeklyTotals: [Int] = Array(repeating: 0, count: 7)

    var fillLevel: Double {
        guard goalML > 0 else { return 0 }
        return Double(totalML) / Double(goalML)
    }

    func refresh() {
        goalML = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.dailyWaterGoalML)
        if goalML == 0 { goalML = AppConstants.Water.defaultDailyGoalML }
        weeklyTotals = [1200, 1800, 2500, 2000, 2200, 1500, totalML]
    }

    func logCup() {
        totalML += AppConstants.Water.cupSizeML
        weeklyTotals[6] = totalML
    }
}
