import Foundation

enum NotificationTypes {
    static let workoutReminder = "workout_reminder"
    static let habitReminder = "habit_reminder"
    static let taskDue = "task_due"
    static let waterReminder = "water_reminder"
    static let dailyPlanReady = "daily_plan_ready"
    static let syncComplete = "sync_complete"

    static let all: [String] = [
        workoutReminder,
        habitReminder,
        taskDue,
        waterReminder,
        dailyPlanReady,
        syncComplete
    ]
}
