import SwiftUI

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case forestGreen = "Forest Green"
    case electricIndigo = "Electric Indigo"
    case sunsetCoral = "Sunset Coral"
    case royalViolet = "Royal Violet"
    case deepTeal = "Deep Teal"
    case oceanNavy = "Ocean Navy"
    case darkMode = "Dark Mode"

    var id: String { rawValue }

    var colors: ThemeColors {
        switch self {
        case .forestGreen: .forestGreen
        case .electricIndigo: .electricIndigo
        case .sunsetCoral: .sunsetCoral
        case .royalViolet: .royalViolet
        case .deepTeal: .deepTeal
        case .oceanNavy: .oceanNavy
        case .darkMode: .darkMode
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .darkMode, .oceanNavy: .dark
        default: .light
        }
    }

    /// Maps legacy persisted theme names to current cases.
    static func resolved(from raw: String) -> AppTheme? {
        if let theme = AppTheme(rawValue: raw) { return theme }
        switch raw {
        case "Dark Forest", "Light Clean", "Forest Deep": return .forestGreen
        case "Midnight Blue": return .oceanNavy
        case "Warm Charcoal": return .sunsetCoral
        default: return nil
        }
    }
}

// MARK: - Theme Colors

struct ThemeColors: Equatable {
    let background: Color
    let cardBackground: Color
    let cardBorder: Color
    let accentGreen: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let chipBackground: Color
    let chipText: Color
    let navBarBackground: Color
    let waterBlue: Color
    let streakRing: Color
    let textOnBackground: Color

    let headerBackground: Color
    let textMutedOnBackground: Color

    let fieldBackground: Color
    let trackBackground: Color
    let chipDone: Color
    let chipToday: Color
    let chipTomorrow: Color
    let streakPill: Color
    let waterButtonBackground: Color
    let danger: Color
    let percentageOrange: Color

    // MARK: Accent exploration themes (coloured header + white body)

    static let forestGreen = exploration(
        headerBackground: Color(hex: "#1A6B35"),
        accentGreen: Color(hex: "#22C55E"),
        navBarBackground: Color(red: 220 / 255, green: 252 / 255, blue: 231 / 255).opacity(0.92),
        chipDone: Color(hex: "#E8F8EF"),
        streakRing: Color.white.opacity(0.2)
    )

    static let electricIndigo = exploration(
        headerBackground: Color(hex: "#3730A3"),
        accentGreen: Color(hex: "#6366F1"),
        navBarBackground: Color(red: 224 / 255, green: 231 / 255, blue: 255 / 255).opacity(0.92),
        chipDone: Color(hex: "#EEF2FF"),
        streakRing: Color.white.opacity(0.2)
    )

    static let sunsetCoral = exploration(
        headerBackground: Color(hex: "#C2410C"),
        accentGreen: Color(hex: "#F97316"),
        navBarBackground: Color(red: 255 / 255, green: 237 / 255, blue: 213 / 255).opacity(0.92),
        chipDone: Color(hex: "#FFEDD5"),
        streakRing: Color.white.opacity(0.2)
    )

    static let royalViolet = exploration(
        headerBackground: Color(hex: "#7E22CE"),
        accentGreen: Color(hex: "#A855F7"),
        navBarBackground: Color(red: 243 / 255, green: 232 / 255, blue: 255 / 255).opacity(0.92),
        chipDone: Color(hex: "#F3E8FF"),
        streakRing: Color.white.opacity(0.2)
    )

    static let deepTeal = exploration(
        headerBackground: Color(hex: "#0F766E"),
        accentGreen: Color(hex: "#14B8A6"),
        navBarBackground: Color(red: 204 / 255, green: 251 / 255, blue: 241 / 255).opacity(0.92),
        chipDone: Color(hex: "#CCFBF1"),
        streakRing: Color.white.opacity(0.2)
    )

    // MARK: Ocean Navy (dark blue — matches water card reference)

    static let oceanNavy = ThemeColors(
        background: Color(hex: "#0B141E"),
        cardBackground: Color(hex: "#121C28"),
        cardBorder: Color.white.opacity(0.1),
        accentGreen: Color(hex: "#4A90E2"),
        textPrimary: Color(hex: "#FFFFFF"),
        textSecondary: Color(hex: "#8BA3C7"),
        textTertiary: Color(hex: "#5C6F8A"),
        chipBackground: Color(hex: "#1A2838"),
        chipText: Color(hex: "#E8EEF7"),
        navBarBackground: Color(hex: "#152030").opacity(0.92),
        waterBlue: Color(hex: "#4A90E2"),
        streakRing: Color.white.opacity(0.15),
        textOnBackground: Color(hex: "#FFFFFF"),
        headerBackground: Color(hex: "#1A2F45"),
        textMutedOnBackground: Color.white.opacity(0.65),
        fieldBackground: Color(hex: "#1A2838"),
        trackBackground: Color(hex: "#243447"),
        chipDone: Color(hex: "#1A3A5C"),
        chipToday: Color(hex: "#2A3548"),
        chipTomorrow: Color(hex: "#1A2F45"),
        streakPill: Color(hex: "#2A3548"),
        waterButtonBackground: Color(hex: "#1A3A5C"),
        danger: Color(hex: "#FF4444"),
        percentageOrange: Color(hex: "#FF6B35")
    )

    // MARK: Dark charcoal theme (Caveman)

    static let darkMode = ThemeColors(
        background: Color(hex: "#1A1A1A"),
        cardBackground: Color(hex: "#2A2A2A"),
        cardBorder: Color.white.opacity(0.08),
        accentGreen: Color(hex: "#22C55E"),
        textPrimary: Color(hex: "#FFFFFF"),
        textSecondary: Color(hex: "#9CA3AF"),
        textTertiary: Color(hex: "#6B7280"),
        chipBackground: Color(hex: "#333333"),
        chipText: Color(hex: "#FFFFFF"),
        navBarBackground: Color(red: 30 / 255, green: 60 / 255, blue: 30 / 255).opacity(0.85),
        waterBlue: Color(hex: "#4A90E2"),
        streakRing: Color.white.opacity(0.15),
        textOnBackground: Color(hex: "#FFFFFF"),
        headerBackground: Color(hex: "#1A6B35"),
        textMutedOnBackground: Color.white.opacity(0.65),
        fieldBackground: Color(hex: "#2C2C2E"),
        trackBackground: Color(hex: "#3A3A3C"),
        chipDone: Color(hex: "#1A3D2A"),
        chipToday: Color(hex: "#3D3419"),
        chipTomorrow: Color(hex: "#1A2D4D"),
        streakPill: Color(hex: "#3D2A1A"),
        waterButtonBackground: Color(hex: "#1A3A5C"),
        danger: Color(hex: "#FF4444"),
        percentageOrange: Color(hex: "#FF6B35")
    )

    private static func exploration(
        headerBackground: Color,
        accentGreen: Color,
        navBarBackground: Color,
        chipDone: Color,
        streakRing: Color
    ) -> ThemeColors {
        ThemeColors(
            background: Color(hex: "#F8F9FA"),
            cardBackground: Color(hex: "#FFFFFF"),
            cardBorder: Color.black.opacity(0.06),
            accentGreen: accentGreen,
            textPrimary: Color(hex: "#0D0D0D"),
            textSecondary: Color(hex: "#6B7280"),
            textTertiary: Color(hex: "#9CA3AF"),
            chipBackground: Color(hex: "#F3F4F6"),
            chipText: Color(hex: "#374151"),
            navBarBackground: navBarBackground,
            waterBlue: Color(hex: "#4A90E2"),
            streakRing: streakRing,
            textOnBackground: Color(hex: "#FFFFFF"),
            headerBackground: headerBackground,
            textMutedOnBackground: Color.white.opacity(0.65),
            fieldBackground: Color(hex: "#F9FAFB"),
            trackBackground: Color(hex: "#E5E7EB"),
            chipDone: chipDone,
            chipToday: Color(hex: "#FEF3C7"),
            chipTomorrow: Color(hex: "#DBEAFE"),
            streakPill: Color(hex: "#FFF7ED"),
            waterButtonBackground: chipDone,
            danger: Color(hex: "#FF4444"),
            percentageOrange: Color(hex: "#FF6B35")
        )
    }
}
