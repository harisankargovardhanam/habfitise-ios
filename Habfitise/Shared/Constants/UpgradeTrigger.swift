import Foundation

enum UpgradeTrigger: String, CaseIterable, Identifiable {
    case aiDailyPlan
    case healthKitSync
    case unlimitedHabits
    case cloudSync
    case advancedAnalytics
    case customReminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiDailyPlan: "AI Daily Planner"
        case .healthKitSync: "Apple Health Sync"
        case .unlimitedHabits: "Unlimited Habits"
        case .cloudSync: "Cloud Sync"
        case .advancedAnalytics: "Advanced Analytics"
        case .customReminders: "Custom Reminders"
        }
    }

    var message: String {
        switch self {
        case .aiDailyPlan:
            "Let AI build your perfect daily schedule."
        case .healthKitSync:
            "Connect Apple Watch and Health data."
        case .unlimitedHabits:
            "Track more than 3 habits with Pro."
        case .cloudSync:
            "Keep data synced across all devices."
        case .advancedAnalytics:
            "Unlock detailed progress insights."
        case .customReminders:
            "Set smart reminders for every routine."
        }
    }
}
