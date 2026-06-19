import SwiftUI

struct HabfitiseAuthTextFieldStyle: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    func body(content: Content) -> some View {
        content
            .font(HabfitiseTypography.body)
            .foregroundStyle(theme.colors.textPrimary)
            .padding(HabfitiseSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: HabfitiseRadius.md)
                    .fill(theme.colors.fieldBackground)
            )
    }
}

extension View {
    func habfitiseAuthTextFieldStyle() -> some View {
        modifier(HabfitiseAuthTextFieldStyle())
    }
}

struct HabfitiseScalePressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var hapticOnPress: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(HabfitiseAnimation.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed, hapticOnPress {
                    HabfitiseHaptics.primaryButton()
                }
            }
    }
}

struct AuthBottomCard<Content: View>: View {
    @Environment(ThemeManager.self) private var theme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, HabfitiseSpacing.xxl)
            .padding(.top, HabfitiseSpacing.xxxl)
            .padding(.bottom, HabfitiseSpacing.xxxl)
            .frame(maxWidth: .infinity, alignment: .leading)
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

struct AuthOrDivider: View {
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            line
            Text("or")
                .font(HabfitiseTypography.subheadline)
                .foregroundStyle(theme.colors.textSecondary)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(theme.colors.chipBackground)
            .frame(height: 1)
    }
}
