import SwiftUI

enum BentoDashboardTheme {
    static let cobalt = Color(hex: "#0047FF")
    static let cobaltDeep = Color(hex: "#0038CC")
    static let cobaltMuted = Color.white.opacity(0.28)
    static let sheet = Color.white
    static let label = Color(hex: "#9CA3AF")
    static let ink = Color(hex: "#0D0D0D")
    static let softFill = Color(hex: "#F3F4F6")

    static let sheetRadius: CGFloat = 32
    static let cardRadius: CGFloat = 20
    static let pillRadius: CGFloat = 999
}

enum BentoMetricsPeriod: String, CaseIterable, Identifiable {
    case day = "D"
    case week = "W"
    case month = "M"

    var id: String { rawValue }
}

struct BentoActivityBar: Identifiable {
    let id: String
    let label: String
    let value: Double
    let isCurrent: Bool
}
