import SwiftUI

struct LiquidGlassTabBar: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(TabBarState.self) private var tabBarState
    @Namespace private var tabIndicatorNamespace

    private var usesLightTabChrome: Bool {
        theme.preferredColorScheme == .light
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                tabItem(tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, compactBar ? TabBarLayout.tabSpacingCompact : TabBarLayout.tabSpacing)
        .padding(.vertical, TabBarLayout.capsulePadding)
        .background { glassBackground }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
        .padding(.horizontal, TabBarLayout.edgeInset)
    }

    private var compactBar: Bool {
        MainTab.allCases.count > 4
    }

    @ViewBuilder
    private func tabItem(_ tab: MainTab) -> some View {
        let isActive = tabBarState.activeTab == tab
        let pillWidth = compactBar ? TabBarLayout.activePillWidthCompact : TabBarLayout.activePillWidth
        let pillHeight = compactBar ? TabBarLayout.activePillHeightCompact : TabBarLayout.activePillHeight
        let iconPointSize = compactBar ? TabBarLayout.iconSizeCompact : TabBarLayout.iconSize

        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                tabBarState.selectTab(tab)
            }
        } label: {
            Image(systemName: tab.systemImage)
                .font(.system(size: iconPointSize, weight: isActive ? .semibold : .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tabIconColor(isActive: isActive))
                .frame(width: pillWidth, height: pillHeight)
                .background {
                    if isActive {
                        Capsule()
                            .fill(activePillFill)
                            .matchedGeometryEffect(id: "tabIndicator", in: tabIndicatorNamespace)
                    }
                }
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.94))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func tabIconColor(isActive: Bool) -> Color {
        if usesLightTabChrome {
            return Color.black.opacity(isActive ? 1 : 0.45)
        }
        return Color.white.opacity(isActive ? 1 : 0.58)
    }

    private var activePillFill: Color {
        if usesLightTabChrome {
            return Color.black.opacity(0.08)
        }
        return Color.black.opacity(0.44)
    }

    private var glassBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .strokeBorder(
                        usesLightTabChrome
                            ? Color.black.opacity(0.08)
                            : Color.white.opacity(0.24),
                        lineWidth: 0.5
                    )
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
                rescheduleNotifications()
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
                    rescheduleNotifications()
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

    private func rescheduleNotifications() {
        guard let userId = appState.authenticatedUserId else { return }
        Task {
            await NotificationService.shared.rescheduleAllReminders(
                userId: userId,
                context: modelContext
            )
        }
    }

    @ViewBuilder
    private var tabShell: some View {
        legacyTabView
    }

    private var legacyTabView: some View {
        Group {
            switch tabBarState.activeTab {
            case .home:
                HomeView()
            case .habits:
                HabitsView()
            case .tasks:
                TasksView()
            case .workout:
                WorkoutsView()
            case .progress:
                ProgressDashboardView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            LiquidGlassTabBar()
                .padding(.bottom, TabBarLayout.floatingBottomInset)
                .offset(y: tabBarState.isVisible ? 0 : TabBarLayout.hideOffset)
                .opacity(tabBarState.isVisible ? 1 : 0)
                .animation(.spring(response: 0.38, dampingFraction: 0.84), value: tabBarState.isVisible)
                .allowsHitTesting(tabBarState.isVisible)
        }
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
