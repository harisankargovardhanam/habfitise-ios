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

// MARK: - Tab page layout

/// Bordered card for tab screen sections.
struct HabfitiseSectionCard<Content: View>: View {
    @Environment(ThemeManager.self) private var theme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            content()
        }
        .padding(HabfitiseSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HabfitiseRadius.lg, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: HabfitiseRadius.lg, style: .continuous)
                .strokeBorder(theme.colors.cardBorder, lineWidth: 1)
        }
    }
}

/// Page title row for tab screens — sits on the standard background.
struct HabfitiseTabPageHeader<Trailing: View>: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let title: String
    var showsBackButton: Bool
    var appliesTopSafeArea: Bool
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        showsBackButton: Bool = false,
        appliesTopSafeArea: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.appliesTopSafeArea = appliesTopSafeArea
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            HStack(alignment: .center, spacing: HabfitiseSpacing.md) {
                if showsBackButton {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)

                Spacer(minLength: 8)

                trailing()
            }
        }
        .padding(.horizontal, HabfitiseSpacing.lg)
        .modifier(TopSafeAreaPaddingModifier(enabled: appliesTopSafeArea))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TopSafeAreaPaddingModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.safeAreaPadding(.top, HabfitiseSpacing.sm)
        } else {
            content
        }
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

// MARK: - Full-screen bounds

/// Keeps full-screen modal content within the visible screen width.
/// Prevents wide ScrollView children from expanding headers and toolbars off-screen.
private struct FullScreenWidthBoundsModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }
}

// MARK: - View Extensions

extension View {
    func fullScreenWidthBounds() -> some View {
        modifier(FullScreenWidthBoundsModifier())
    }

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
