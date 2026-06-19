import Foundation

enum LocalSessionService {
    static func currentUserId() -> String? {
        UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.localUserId)
    }

    @discardableResult
    static func ensureUser() -> String {
        if let existing = currentUserId() {
            return existing
        }

        let userId = UUID().uuidString
        UserDefaults.standard.set(userId, forKey: AppConstants.UserDefaultsKeys.localUserId)
        return userId
    }

    static func clearSession() {
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.localUserId)
    }
}
