import Foundation

enum AppConstants {
    static let appName = "Habfitise"
    static let minimumIOSVersion = "17.0"

    /// When true, all data stays on-device (SwiftData). Supabase auth, sync, and edge functions are skipped.
    enum Backend {
        static let useLocalOnly = true
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
        static let dailyWaterGoalML = "dailyWaterGoalML"
        static let lastSuccessfulSyncAt = "lastSuccessfulSyncAt"
        static let localUserId = "localUserId"
        static let appAppearance = "appAppearance"
        static let appTheme = "appTheme"
        static let generatedWorkoutPlanJSON = "generatedWorkoutPlanJSON"
        static let dismissedWorkoutSuggestion = "dismissedWorkoutSuggestion"
        static let preferredWorkoutTime = "preferredWorkoutTime"
    }

    enum Notifications {
        static let workoutReminderCategory = "WORKOUT_REMINDER"
        static let missedWorkoutCategory = "MISSED_WORKOUT"
        static let actionStart = "START_WORKOUT"
        static let actionSnooze = "SNOOZE_1HR"
        static let actionPushTomorrow = "PUSH_TOMORROW"
        static let actionSkip = "SKIP_WORKOUT"
        static let userInfoTemplateId = "templateId"
        static let userInfoMissedId = "missedId"
    }

    enum Sync {
        static let batchSize = 50
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
    }

    enum Auth {
        static let oauthRedirectURL = URL(string: "habfitise://auth-callback")!
        static let oauthCallbackScheme = "habfitise"
    }

    /// Paid Apple Developer Program capabilities — off for Personal Team dev.
    enum Capabilities {
        static let signInWithApple = false
        static let healthKit = false
    }

    enum RevenueCatConfig {
        static let placeholderPrefixes = ["placeholder", "your-revenuecat"]
    }
}
