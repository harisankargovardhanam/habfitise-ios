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

enum PendingNavigation: Equatable {
    case none
    case onboarding
    case auth
    case home
    case settings
    case upgrade(UpgradeTrigger)
}
