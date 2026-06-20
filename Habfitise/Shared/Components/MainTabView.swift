import SwiftUI

struct LiquidGlassTabBar: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(TabBarState.self) private var tabBarState

    private let edgeInset: CGFloat = 20

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: 6) {
                ForEach(MainTab.allCases) { tab in
                    tabItem(tab)
                }
            }
            .padding(6)
            .background { glassBackground }
            .clipShape(Capsule())

            Spacer(minLength: 0)
        }
        .padding(.horizontal, edgeInset)
        .padding(.bottom, edgeInset)
        .animation(HabfitiseAnimation.tabTransition, value: tabBarState.activeTab)
        .animation(HabfitiseAnimation.tabTransition, value: tabBarState.isVisible)
    }

    @ViewBuilder
    private func tabItem(_ tab: MainTab) -> some View {
        let isActive = tabBarState.activeTab == tab

        Button {
            tabBarState.selectTab(tab)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .habfitiseTabBounce(isActive: isActive)

                if isActive {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .foregroundStyle(isActive ? BentoDashboardTheme.cobalt : Color.white.opacity(0.88))
            .padding(.horizontal, isActive ? 16 : 14)
            .padding(.vertical, 12)
            .background {
                if isActive {
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: BentoDashboardTheme.cobalt.opacity(0.2), radius: 10, y: 4)
                }
            }
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.96))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var glassBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .fill(BentoDashboardTheme.cobalt.opacity(0.58))
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            }
    }
}

struct MainTabView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService

    @State private var tabBarState = TabBarState()
    @Bindable private var missedWorkoutService = MissedWorkoutService.shared
    @Bindable private var notificationBridge = WorkoutNotificationBridge.shared

    var body: some View {
        tabShell
            .environment(tabBarState)
            .background(theme.colors.background.ignoresSafeArea())
            .onAppear {
                runMissedWorkoutDetection()
                guard !AppConstants.Backend.useLocalOnly else { return }
                syncService.configure(modelContext: modelContext) {
                    appState.authenticatedUserId
                }
                syncService.startNetworkMonitoring()
                Task {
                    await syncService.syncAll(
                        modelContext: modelContext,
                        userId: appState.authenticatedUserId
                    )
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    runMissedWorkoutDetection()
                }
                guard !AppConstants.Backend.useLocalOnly else { return }
                if newPhase == .active {
                    Task {
                        await syncService.syncAll(
                            modelContext: modelContext,
                            userId: appState.authenticatedUserId
                        )
                    }
                }
            }
            .onChange(of: notificationBridge.pendingBuilder?.workoutType) { _, _ in
                if notificationBridge.pendingBuilder != nil {
                    tabBarState.selectTab(.home)
                }
            }
            .sheet(item: $missedWorkoutService.proactiveSheetItem) { item in
                MissedWorkoutSheet(
                    item: item,
                    onConfirm: {
                        missedWorkoutService.clearProactiveSheet()
                    },
                    onDismissWithoutConfirm: {
                        missedWorkoutService.dismissProactiveSheet(for: item.id)
                    }
                )
            }
    }

    private func runMissedWorkoutDetection() {
        guard let userId = appState.authenticatedUserId else { return }
        missedWorkoutService.detectMissedWorkouts(userId: userId, context: modelContext)
        missedWorkoutService.evaluateProactiveSheet(
            userId: userId,
            context: modelContext,
            themeManager: theme
        )
    }

    @ViewBuilder
    private var tabShell: some View {
        legacyTabView
    }

    private var legacyTabView: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tabBarState.activeTab {
                case .home:
                    HomeView()
                case .workout:
                    WorkoutsView()
                case .progress:
                    ProgressDashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(tabTransition)
            .id(tabBarState.activeTab)

            LiquidGlassTabBar()
        }
        .animation(HabfitiseAnimation.tabTransition, value: tabBarState.activeTab)
    }

    private var tabTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: tabBarState.tabTransitionForward ? .trailing : .leading),
            removal: .move(edge: tabBarState.tabTransitionForward ? .leading : .trailing)
        )
    }
}

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environment(AppState())
            .environment(SyncService())
            .environment(ThemeManager())
    }
}
#endif
