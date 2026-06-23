import SwiftUI
import SwiftData

@main
struct HabfitiseApp: App {
    @State private var appState = AppState()
    @State private var syncService = SyncService()
    @State private var themeManager = ThemeManager()

    private var modelContainer: ModelContainer {
        SwiftDataStack.shared.container
    }

    init() {
        configureThirdPartyServices()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(syncService)
                .environment(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .modelContainer(modelContainer)
                .onOpenURL { url in
                    guard !AppConstants.Backend.useLocalOnly else { return }
                    Task {
                        do {
                            try await SupabaseManager.shared.handleDeepLink(url)
                            if let session = await SupabaseManager.shared.currentSession() {
                                appState.setAuthenticated(
                                    userId: session.user.id.uuidString,
                                    context: SwiftDataStack.shared.mainContext
                                )
                            }
                        } catch {
                            appState.setAuthError(error.localizedDescription)
                        }
                    }
                }
                .task {
                    await bootstrapAuthState()
                }
                .task {
                    await bootstrapServices()
                }
                .task(id: appState.authenticatedUserId) {
                    guard !AppConstants.Backend.useLocalOnly,
                          let userId = appState.authenticatedUserId else { return }

                    let context = SwiftDataStack.shared.mainContext
                    syncService.configure(modelContext: context) {
                        appState.authenticatedUserId
                    }
                    syncService.startNetworkMonitoring()

                    let showRestoreUI = appState.isRestoringFromCloud
                    await syncService.syncAll(
                        modelContext: context,
                        userId: userId,
                        showProgress: showRestoreUI
                    )

                    if showRestoreUI {
                        appState.finishCloudRestore(context: context)
                    }

                    await NotificationService.shared.rescheduleAllReminders(
                        userId: userId,
                        context: context
                    )
                }
        }
    }

    private func configureThirdPartyServices() {
        NotificationService.shared.configure()
        if let revenueCatKey = Bundle.main.object(forInfoDictionaryKey: AppConstants.RevenueCat.apiKeyKey) as? String {
            PurchaseService.shared.configure(apiKey: revenueCatKey)
        }
    }

    @MainActor
    private func bootstrapAuthState() async {
        if AppConstants.Backend.useLocalOnly {
            if let userId = LocalSessionService.currentUserId() {
                appState.setAuthenticated(
                    userId: userId,
                    context: SwiftDataStack.shared.mainContext
                )
            } else {
                appState.authState = .unauthenticated
            }
            return
        }

        guard SupabaseManager.shared.isConfigured else {
            appState.authState = .error(SupabaseManagerError.notConfigured.localizedDescription)
            return
        }

        for await state in SupabaseManager.shared.authStateStream {
            switch state {
            case .loading:
                appState.authState = .loading

            case .authenticated(let userId):
                appState.setAuthenticated(
                    userId: userId,
                    context: SwiftDataStack.shared.mainContext
                )

            case .unauthenticated:
                appState.authState = .unauthenticated
                appState.needsOnboarding = false

            case .error(let message):
                appState.authState = .error(message)
            }
        }
    }

    @MainActor
    private func bootstrapServices() async {
        if PurchaseService.shared.isConfigured {
            if PurchaseService.shared.customerInfo == nil {
                if let info = try? await PurchaseService.shared.refreshCustomerInfo() {
                    appState.isPro = info.entitlements[AppConstants.RevenueCat.proEntitlementID]?.isActive == true
                }
            } else {
                appState.isPro = PurchaseService.shared.isProActive
            }
        }

        // Local notifications only. Remote push (FCM) deferred — see Config/DEFERRED.md
        _ = try? await NotificationService.shared.requestAuthorization()
        let context = SwiftDataStack.shared.mainContext
        await NotificationService.shared.pruneStaleWaterReminders(
            activeUserId: appState.authenticatedUserId,
            context: context
        )
        if let userId = appState.authenticatedUserId {
            await NotificationService.shared.rescheduleAllReminders(
                userId: userId,
                context: context
            )
        } else {
            NotificationService.shared.resetAllReminders()
        }
    }
}
