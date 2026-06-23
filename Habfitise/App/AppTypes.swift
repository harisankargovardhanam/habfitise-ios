import Foundation

enum AuthState: Equatable {
    case loading
    case authenticated(userId: String)
    case unauthenticated
    case error(String)
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
}

enum SyncPhase: Equatable {
    case idle
    case connecting
    case downloading
    case downloadingProfile
    case downloadingWorkouts
    case downloadingSets
    case downloadingHabits
    case downloadingHabitCompletions
    case downloadingTasks
    case downloadingMood
    case downloadingWater
    case downloadingWaterGoals
    case uploading
    case finishing

    var message: String {
        switch self {
        case .idle:
            ""
        case .connecting:
            "Connecting to your account…"
        case .downloading, .downloadingProfile:
            "Restoring your profile…"
        case .downloadingWorkouts, .downloadingSets:
            "Pulling workout history…"
        case .downloadingHabits, .downloadingHabitCompletions:
            "Syncing habits…"
        case .downloadingTasks:
            "Loading tasks…"
        case .downloadingMood:
            "Loading mood check-ins…"
        case .downloadingWater, .downloadingWaterGoals:
            "Syncing water intake…"
        case .uploading:
            "Saving local changes…"
        case .finishing:
            "Almost ready…"
        }
    }
}

enum PendingNavigation: Equatable {
    case none
    case onboarding
    case auth
    case home
    case settings
    case upgrade(UpgradeTrigger)
}
