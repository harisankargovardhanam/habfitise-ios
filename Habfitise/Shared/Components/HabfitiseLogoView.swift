import SwiftUI

enum LaunchSplashMode {
    case startup
    case syncing
}

/// Single launch surface — logo + live status (replaces separate loading + welcome-back screens).
struct LaunchSplashView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SyncService.self) private var syncService

    var mode: LaunchSplashMode = .startup

    @State private var pulse = false
    @State private var ringRotation: Double = 0

    var body: some View {
        ZStack {
            themeManager.colors.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    themeManager.colors.accentGreen.opacity(mode == .syncing ? 0.12 : 0.08),
                    themeManager.colors.background
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: HabfitiseSpacing.xl) {
                Spacer()

                ZStack {
                    if mode == .syncing {
                        Circle()
                            .stroke(
                                themeManager.colors.accentGreen.opacity(0.14),
                                lineWidth: 3
                            )
                            .frame(width: 108, height: 108)

                        Circle()
                            .trim(from: 0.08, to: 0.92)
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        themeManager.colors.accentGreen.opacity(0.12),
                                        themeManager.colors.accentGreen,
                                        themeManager.colors.accentGreen.opacity(0.12)
                                    ],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 108, height: 108)
                            .rotationEffect(.degrees(ringRotation))
                    }

                    HabfitiseLogoView(height: 52, maxWidth: 200, style: .automatic)
                        .scaleEffect(mode == .syncing && pulse ? 1.02 : 0.98)
                }

                Text(statusMessage)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: statusMessage)
                    .padding(.horizontal, HabfitiseSpacing.xxxl)

                if mode == .syncing {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(themeManager.colors.accentGreen)
                                .frame(width: 6, height: 6)
                                .opacity(pulse ? 1 : 0.35)
                                .animation(
                                    .easeInOut(duration: 0.55)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.16),
                                    value: pulse
                                )
                        }
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pulse = true
            if mode == .syncing {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            }
        }
    }

    private var statusMessage: String {
        switch mode {
        case .startup:
            return "Starting VAYA…"
        case .syncing:
            let phase = syncService.syncPhase.message
            if !phase.isEmpty {
                return phase
            }
            if let friendly = syncService.userFacingStatusMessage {
                return friendly
            }
            return "Syncing your data…"
        }
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
