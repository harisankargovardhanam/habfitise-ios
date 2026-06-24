import Foundation

enum WidgetActivityCache {
    private static let stepsKey = "widgetStepsToday"
    private static let stepGoalKey = "widgetStepGoal"
    private static let wellnessKey = "widgetWellnessScore"

    static func save(stepsToday: Int, stepGoal: Int, wellnessScore: Int) {
        guard let defaults = WidgetSnapshotStore.sharedDefaults else { return }
        defaults.set(stepsToday, forKey: stepsKey)
        defaults.set(stepGoal, forKey: stepGoalKey)
        defaults.set(wellnessScore, forKey: wellnessKey)
    }

    static func load() -> (stepsToday: Int, stepGoal: Int, wellnessScore: Int) {
        guard let defaults = WidgetSnapshotStore.sharedDefaults else {
            return (0, AppConstants.Health.defaultStepGoal, 0)
        }
        let steps = defaults.integer(forKey: stepsKey)
        let goal = defaults.integer(forKey: stepGoalKey)
        let wellness = defaults.integer(forKey: wellnessKey)
        return (
            steps,
            goal > 0 ? goal : AppConstants.Health.defaultStepGoal,
            wellness
        )
    }
}
