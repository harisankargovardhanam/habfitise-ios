import SwiftUI

/// Full-screen restore UI shown while cloud data is pulled on sign-in.
struct CloudRestoreView: View {
    @Environment(SyncService.self) private var syncService
    @Environment(ThemeManager.self) private var themeManager

    @State private var pulse = false
    @State private var ringRotation: Double = 0

    private var statusMessage: String {
        let phaseMessage = syncService.syncPhase.message
        if !phaseMessage.isEmpty {
            return phaseMessage
        }
        if let error = syncService.lastErrorMessage {
            return error
        }
        return "Syncing your data…"
    }

    var body: some View {
        ZStack {
            themeManager.colors.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    themeManager.colors.accentGreen.opacity(0.14),
                    themeManager.colors.background
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: HabfitiseSpacing.xxl) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(
                            themeManager.colors.accentGreen.opacity(0.15),
                            lineWidth: 3
                        )
                        .frame(width: 112, height: 112)

                    Circle()
                        .trim(from: 0.08, to: 0.92)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    themeManager.colors.accentGreen.opacity(0.15),
                                    themeManager.colors.accentGreen,
                                    themeManager.colors.accentGreen.opacity(0.15)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 112, height: 112)
                        .rotationEffect(.degrees(ringRotation))

                    HabfitiseLogoView(height: 44, maxWidth: 180)
                        .scaleEffect(pulse ? 1.03 : 0.97)
                }

                VStack(spacing: HabfitiseSpacing.sm) {
                    Text("Welcome back")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.colors.textPrimary)

                    Text(statusMessage)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.35), value: statusMessage)
                        .padding(.horizontal, HabfitiseSpacing.xxl)
                }

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(themeManager.colors.accentGreen)
                            .frame(width: 7, height: 7)
                            .opacity(pulse ? 1 : 0.35)
                            .animation(
                                .easeInOut(duration: 0.55)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.18),
                                value: pulse
                            )
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            pulse = true
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }
}

#if DEBUG
struct CloudRestoreView_Previews: PreviewProvider {
    static var previews: some View {
        CloudRestoreView()
            .environment(SyncService())
            .environment(ThemeManager())
    }
}
#endif
