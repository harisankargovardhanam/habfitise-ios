import SwiftUI

// MARK: - Design tokens

enum BentoCardStyle {
    static let cornerRadius: CGFloat = 20
    static let contentPadding: CGFloat = 16
    static let compactContentPadding: CGFloat = 16
    static let headerIconSize: CGFloat = 16
    static let metricCellHeight: CGFloat = 148
    static let compactSquareHeight: CGFloat = 148
    static let metricGridSpacing: CGFloat = 16
    static let compactContentSpacing: CGFloat = 6
    static let headerContentSpacing: CGFloat = 6

    static let shadowColor = Color.black.opacity(0.04)
    static let shadowRadius: CGFloat = 10
    static let shadowX: CGFloat = 0
    static let shadowY: CGFloat = 4
}

// MARK: - Card accent (icon + focal color per domain)

enum BentoCardAccent {
    case activity
    case workout
    case habits
    case tasks
    case water
    case streak
    case mood
    case bodyWeight
    case health
    case nutrition

    var systemImage: String {
        switch self {
        case .activity: "chart.bar.fill"
        case .workout: "dumbbell.fill"
        case .habits: "leaf.fill"
        case .tasks: "checklist"
        case .water: "drop.fill"
        case .streak: "flame.fill"
        case .mood: "bolt.heart.fill"
        case .bodyWeight: "figure.stand"
        case .health: "heart.fill"
        case .nutrition: "fork.knife"
        }
    }

    func focalColor(in colors: ThemeColors) -> Color {
        switch self {
        case .activity: colors.accentGreen
        case .workout: colors.accentGreen
        case .habits: colors.accentGreen
        case .tasks: colors.accentGreen
        case .water: colors.waterBlue
        case .streak: colors.percentageOrange
        case .mood: colors.accentGreen
        case .bodyWeight: colors.accentGreen
        case .health: Color(hex: "#FF375F")
        case .nutrition: Color(hex: "#FF9500")
        }
    }
}

// MARK: - Surface modifier

private struct BentoCardSurfaceModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme
    var compact: Bool

    func body(content: Content) -> some View {
        content
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
            .padding(compact ? BentoCardStyle.compactContentPadding : BentoCardStyle.contentPadding)
            .background(theme.colors.cardBackground)
            .clipShape(
                RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
            )
            .shadow(
                color: BentoCardStyle.shadowColor,
                radius: BentoCardStyle.shadowRadius,
                x: BentoCardStyle.shadowX,
                y: BentoCardStyle.shadowY
            )
    }
}

extension View {
    func bentoCardSurface(compact: Bool = false) -> some View {
        modifier(BentoCardSurfaceModifier(compact: compact))
    }

    /// Shared minimum height for compact half-width bento widgets.
    func bentoCompactSquareCell() -> some View {
        frame(minHeight: BentoCardStyle.compactSquareHeight, alignment: .topLeading)
    }
}

// MARK: - Header

struct BentoCardHeader: View {
    @Environment(ThemeManager.self) private var theme

    let title: String
    let accent: BentoCardAccent
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: HabfitiseSpacing.sm) {
            Group {
                if accent == .water {
                    WaterGlassIcon(isFilled: true, size: BentoCardStyle.headerIconSize)
                } else {
                    Image(systemName: accent.systemImage)
                        .font(.system(size: BentoCardStyle.headerIconSize, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .foregroundStyle(accent.focalColor(in: theme.colors))
            .frame(width: 22, height: 22, alignment: .center)

            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.0)
                .foregroundStyle(theme.colors.textSecondary)

            Spacer(minLength: 4)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent.focalColor(in: theme.colors))
            }
        }
    }
}

// MARK: - Container

/// Unified bento card shell — header, surface, shadow, and grid-safe framing.
struct BentoCardContainer<Content: View>: View {
    let title: String
    let accent: BentoCardAccent
    var actionTitle: String?
    var action: (() -> Void)?
    var compact: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? BentoCardStyle.headerContentSpacing : HabfitiseSpacing.md) {
            BentoCardHeader(
                title: title,
                accent: accent,
                actionTitle: actionTitle,
                action: action
            )
            content()
        }
        .bentoCardSurface(compact: compact)
    }
}

/// Surface-only wrapper for cards with custom header layout.
struct BentoCardSurface<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .bentoCardSurface()
    }
}
