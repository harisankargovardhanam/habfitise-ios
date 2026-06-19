import SwiftUI

@Observable
@MainActor
final class ThemeManager {
    var currentTheme: AppTheme {
        didSet { persist() }
    }

    var colors: ThemeColors {
        currentTheme.colors
    }

    var preferredColorScheme: ColorScheme? {
        currentTheme.preferredColorScheme
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.appTheme),
           let theme = AppTheme.resolved(from: raw) {
            currentTheme = theme
        } else {
            currentTheme = Self.migrateLegacyAppearance()
        }
    }

    func applyTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentTheme = theme
        }
    }

    /// Warm, neutral copy for missed-workout flows. Never guilt-based.
    static let missedWorkoutPrompts: [String] = [
        "Life happens — what should we do?",
        "No worries, let's adjust",
        "Your plan is flexible",
        "Ready when you are",
        "We'll pick up where you left off"
    ]

    func missedWorkoutPrompt(seed: UUID? = nil) -> String {
        let prompts = Self.missedWorkoutPrompts
        guard let seed else {
            return prompts[Int.random(in: 0..<prompts.count)]
        }
        let index = abs(seed.hashValue) % prompts.count
        return prompts[index]
    }

    private func persist() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: AppConstants.UserDefaultsKeys.appTheme)
    }

    private static func migrateLegacyAppearance() -> AppTheme {
        guard let raw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.appAppearance) else {
            return .forestGreen
        }
        switch raw {
        case "light": return .forestGreen
        case "dark": return .darkMode
        default: return .forestGreen
        }
    }
}
