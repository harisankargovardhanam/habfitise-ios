import SwiftUI

struct GoogleGLogo: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)

            Text("G")
                .font(.system(size: size * 0.62, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#4285F4"),
                            Color(hex: "#EA4335"),
                            Color(hex: "#FBBC05"),
                            Color(hex: "#34A853")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: size, height: size)
    }
}

struct GoogleSignInButton: View {
    @Environment(ThemeManager.self) private var theme
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HabfitiseSpacing.md) {
                GoogleGLogo()
                Text("Continue with Google")
                    .font(HabfitiseTypography.button)
                    .foregroundStyle(theme.colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: HabfitiseRadius.lg)
                    .fill(Color.white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: HabfitiseRadius.lg)
                    .strokeBorder(theme.colors.textPrimary, lineWidth: 1)
            }
        }
        .buttonStyle(HabfitiseScalePressButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}
