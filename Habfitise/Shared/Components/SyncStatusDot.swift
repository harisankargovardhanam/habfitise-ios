import SwiftUI

struct SyncStatusDot: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(SyncService.self) private var syncService
    @State private var isPulsing = false
    @State private var showErrorAlert = false

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.4 : 1)
            .animation(pulseAnimation, value: isPulsing)
            .accessibilityLabel(accessibilityLabel)
            .onTapGesture {
                if case .error = syncService.syncStatus {
                    showErrorAlert = true
                }
            }
            .onAppear(perform: updatePulse)
            .onChange(of: syncService.syncStatus) { _, _ in
                updatePulse()
            }
            .alert("Sync Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncService.lastErrorMessage ?? "An unknown sync error occurred.")
            }
    }

    private var dotColor: Color {
        switch syncService.syncStatus {
        case .syncing:
            theme.colors.accentGreen
        case .error:
            theme.colors.danger
        case .idle:
            theme.colors.textSecondary
        }
    }

    private var pulseAnimation: Animation? {
        if case .syncing = syncService.syncStatus {
            .easeInOut(duration: 1).repeatForever(autoreverses: true)
        } else {
            .default
        }
    }

    private var accessibilityLabel: String {
        switch syncService.syncStatus {
        case .syncing: "Syncing"
        case .idle: "Sync idle"
        case .error: "Sync error"
        }
    }

    private func updatePulse() {
        isPulsing = {
            if case .syncing = syncService.syncStatus { return true }
            return false
        }()
    }
}

#if DEBUG
struct SyncStatusDot_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            SyncStatusDotPreview(status: .idle)
            SyncStatusDotPreview(status: .syncing)
            SyncStatusDotPreview(status: .error("Offline"))
        }
        .padding()
        .habfitiseGreenBackground()
        .environment(ThemeManager())
    }

    private struct SyncStatusDotPreview: View {
        @State private var syncService = SyncService()
        let status: SyncStatus

        var body: some View {
            SyncStatusDot()
                .environment(syncService)
                .environment(ThemeManager())
                .onAppear { syncService.syncStatus = status }
        }
    }
}
#endif
