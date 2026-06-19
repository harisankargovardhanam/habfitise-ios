import SwiftUI

// MARK: - Card

struct HabfitiseCardModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.colors.cardBackground)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: HabfitiseRadius.xl,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: HabfitiseRadius.xl
                )
            )
    }
}

struct HabfitiseContentCardModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(theme.colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: HabfitiseRadius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: HabfitiseRadius.xl, style: .continuous)
                    .strokeBorder(theme.colors.cardBorder, lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                radius: 12,
                y: 4
            )
    }
}

// MARK: - Background

struct HabfitiseGreenBackground: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                theme.colors.headerBackground
                    .ignoresSafeArea()
            )
    }
}

struct HabfitiseScreenBackground: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                theme.colors.background
                    .ignoresSafeArea()
            )
    }
}

// MARK: - Primary Button

struct HabfitisePrimaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var theme
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HabfitiseTypography.button)
            .foregroundStyle(theme.colors.textOnBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: HabfitiseRadius.lg)
                    .fill(
                        isEnabled
                            ? theme.colors.accentGreen
                            : theme.colors.accentGreen.opacity(0.4)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(HabfitiseAnimation.buttonPress, value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.6)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed, isEnabled {
                    HabfitiseHaptics.primaryButton()
                }
            }
    }
}

// MARK: - Chip

struct HabfitiseChipStyle: ViewModifier {
    let color: Color
    let textColor: Color

    func body(content: Content) -> some View {
        content
            .font(HabfitiseTypography.caption)
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(color))
    }
}

// MARK: - View Extensions

extension View {
    func habfitiseCard() -> some View {
        modifier(HabfitiseCardModifier())
    }

    func habfitiseContentCard() -> some View {
        modifier(HabfitiseContentCardModifier())
    }

    func habfitiseGreenBackground() -> some View {
        modifier(HabfitiseGreenBackground())
    }

    func habfitiseScreenBackground() -> some View {
        modifier(HabfitiseScreenBackground())
    }

    func habfitiseChipStyle(color: Color, textColor: Color) -> some View {
        modifier(HabfitiseChipStyle(color: color, textColor: textColor))
    }

    /// Backward-compatible alias used by feature screens.
    func habfitiseScreenBackgroundLegacy() -> some View {
        habfitiseGreenBackground()
    }
}
