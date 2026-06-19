import SwiftUI

/// Legacy color access — prefer `@Environment(ThemeManager.self) private var theme` + `theme.colors`.
enum HabfitiseColors {
    static let danger = Color(hex: "#FF4444")
    static let percentageOrange = Color(hex: "#FF6B35")
}
