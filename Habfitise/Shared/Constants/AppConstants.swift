import Foundation

enum AppConstants {
    static let appName = "VAYA"
    static var proProductName: String { "\(appName) Pro" }
    static let minimumIOSVersion = "17.0"

    /// When true, all data stays on-device (SwiftData). Supabase auth, sync, and edge functions are skipped.
    enum Backend {
        static let useLocalOnly = false
    }

    enum Supabase {
        static let urlKey = "SUPABASE_URL"
        static let anonKeyKey = "SUPABASE_ANON_KEY"
    }

    enum RevenueCat {
        static let apiKeyKey = "REVENUECAT_API_KEY"
        static let proEntitlementID = "pro"
    }

    enum EdgeFunctions {
        static let planGenerator = "habfitise-plan-generator"
        static let reschedule = "habfitise-reschedule"
    }

    enum UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"

        /// Per-account onboarding completion (Supabase `userId`).
        static func onboardingCompleted(for userId: String) -> String {
            "onboardingCompleted_\(userId)"
        }

        static func lastSuccessfulSyncAt(for userId: String) -> String {
            "lastSuccessfulSyncAt_\(userId.lowercased())"
        }

        static let dailyWaterGoalML = "dailyWaterGoalML"
        static let lastSuccessfulSyncAt = "lastSuccessfulSyncAt"
        static let localUserId = "localUserId"
        static let appAppearance = "appAppearance"
        static let appTheme = "appTheme"
        static let generatedWorkoutPlanJSON = "generatedWorkoutPlanJSON"
        static let dismissedWorkoutSuggestion = "dismissedWorkoutSuggestion"
        static let preferredWorkoutTime = "preferredWorkoutTime"
        static let notificationsEnabled = "notificationsEnabled"
        /// Debug toggle in Profile — forces Pro (incl. cloud sync) for testing.
        static let debugForcePro = "debugForcePro"
    }

    enum Notifications {
        static let workoutReminderCategory = "WORKOUT_REMINDER"
        static let missedWorkoutCategory = "MISSED_WORKOUT"
        static let habitReminderCategory = "HABIT_REMINDER"
        static let waterReminderCategory = "WATER_REMINDER"
        static let actionStart = "START_WORKOUT"
        static let actionSnooze = "SNOOZE_1HR"
        static let actionPushTomorrow = "PUSH_TOMORROW"
        static let actionSkip = "SKIP_WORKOUT"
        static let userInfoTemplateId = "templateId"
        static let userInfoMissedId = "missedId"
        static let userInfoHabitId = "habitId"
        static let userInfoUserId = "userId"
        static let userInfoNotificationType = "notificationType"
    }

    enum Sync {
        static let batchSize = 50
        /// Minimum seconds between automatic background syncs.
        static let minimumIntervalSeconds: TimeInterval = 60
        /// Overlap window subtracted from last sync time for incremental pulls.
        static let overlapSeconds: TimeInterval = 300
    }

    /// Bump when making breaking SwiftData schema changes (new store file is created).
    enum SwiftData {
        static let schemaVersion = 3
        static var storeFileName: String { "habfitise-v\(schemaVersion).store" }
    }

    enum Water {
        static let defaultDailyGoalML = 2500
        static let cupSizeML = 250
        static let dropLogML = 350
        /// Minimum spacing between hydration nudges.
        static let minimumReminderIntervalMinutes = 90
        /// Default interval when no `WaterGoal` record exists.
        static let defaultReminderIntervalMinutes = 120
        /// Max pending hydration reminders scheduled at once.
        static let maxPendingReminders = 6
    }

    enum Auth {
        static let oauthRedirectURL = URL(string: "habfitise://auth-callback")!
        static let oauthCallbackScheme = "habfitise"
    }

    /// Sign In with Apple requires paid Apple Developer Program — off for Personal Team.
    enum Capabilities {
        static let signInWithApple = false
        static let healthKit = false
    }

    enum RevenueCatConfig {
        static let placeholderPrefixes = ["placeholder", "your-revenuecat"]
    }
}
