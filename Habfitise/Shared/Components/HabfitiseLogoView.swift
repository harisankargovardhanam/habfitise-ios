import SwiftUI

/// Centered launch / loading splash — theme background with the matching logo variant.
struct LaunchSplashView: View {
    @Environment(ThemeManager.self) private var themeManager

    var logoHeight: CGFloat = 56
    var logoMaxWidth: CGFloat = 220

    var body: some View {
        ZStack {
            themeManager.colors.background
                .ignoresSafeArea()

            HabfitiseLogoView(
                height: logoHeight,
                maxWidth: logoMaxWidth,
                style: .automatic
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Wide VAYA wordmark — `VayaLogo` (light letters) or `VayaLogoLight` (dark letters).
struct HabfitiseLogoView: View {
    @Environment(ThemeManager.self) private var theme

    var height: CGFloat = 40
    var maxWidth: CGFloat?
    var style: VayaLogoStyle = .automatic

    enum VayaLogoStyle {
        /// Light wordmark for dark backgrounds.
        case onDarkBackground
        /// Dark wordmark for light backgrounds.
        case onLightBackground
        /// Picks variant from the active theme.
        case automatic
    }

    private var usesLightBackgroundStyle: Bool {
        switch style {
        case .onDarkBackground:
            false
        case .onLightBackground:
            true
        case .automatic:
            theme.currentTheme.preferredColorScheme != .dark
        }
    }

    private var imageName: String {
        usesLightBackgroundStyle ? "VayaLogoLight" : "VayaLogo"
    }

    private var logoSize: CGSize {
        let width = maxWidth ?? 220
        return CGSize(width: width, height: height)
    }

    var body: some View {
        Image(imageName, bundle: .main)
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: logoSize.width, height: logoSize.height)
            .accessibilityLabel(AppConstants.appName)
    }
}

#if DEBUG
struct HabfitiseLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            HabfitiseLogoView(height: 32, style: .onDarkBackground)
                .padding()
                .background(Color(hex: "#1A1A1A"))
            HabfitiseLogoView(height: 32, style: .onLightBackground)
                .padding()
                .background(Color(hex: "#F8F9FA"))
        }
    }
}
#endif
