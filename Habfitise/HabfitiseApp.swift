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
                        try? await SupabaseManager.shared.handleDeepLink(url)
                    }
                }
                .task {
                    await bootstrapAuthState()
                }
                .task {
                    await bootstrapServices()
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
        await rescheduleWorkoutReminders()
    }

    @MainActor
    private func rescheduleWorkoutReminders() async {
        guard let userId = appState.authenticatedUserId else { return }
        let userIdConst = userId
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.userId == userIdConst && $0.nextScheduledAt != nil }
        )
        let templates = (try? SwiftDataStack.shared.mainContext.fetch(descriptor)) ?? []
        for template in templates {
            await NotificationService.shared.scheduleWorkoutReminder(template: template)
        }
    }
}
