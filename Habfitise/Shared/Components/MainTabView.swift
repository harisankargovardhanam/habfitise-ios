import SwiftUI

struct LiquidGlassTabBar: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(TabBarState.self) private var tabBarState
    @Namespace private var tabIndicatorNamespace

    private var usesLightTabChrome: Bool {
        theme.preferredColorScheme == .light
    }

    var body: some View {
        HStack(spacing: TabBarLayout.tabSpacing) {
            ForEach(MainTab.allCases) { tab in
                tabItem(tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, TabBarLayout.capsulePadding)
        .background { glassBackground }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
        .padding(.horizontal, TabBarLayout.edgeInset)
    }

    @ViewBuilder
    private func tabItem(_ tab: MainTab) -> some View {
        let isActive = tabBarState.activeTab == tab

        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                tabBarState.selectTab(tab)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isActive ? tab.filledSystemImage : tab.outlineSystemImage)
                    .font(.system(size: TabBarLayout.iconSize, weight: isActive ? .semibold : .regular))
                    .symbolRenderingMode(.monochrome)

                Text(tab.shortTitle)
                    .font(.system(size: TabBarLayout.labelSize, weight: isActive ? .semibold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tabLabelColor(isActive: isActive))
            .frame(maxWidth: .infinity)
            .frame(height: TabBarLayout.tabItemHeight)
            .background {
                if isActive {
                    Capsule()
                        .fill(activePillFill)
                        .matchedGeometryEffect(id: "tabIndicator", in: tabIndicatorNamespace)
                }
            }
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.96))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func tabLabelColor(isActive: Bool) -> Color {
        if usesLightTabChrome {
            return Color.black.opacity(isActive ? 1 : 0.42)
        }
        return Color.white.opacity(isActive ? 1 : 0.52)
    }

    private var activePillFill: Color {
        if usesLightTabChrome {
            return Color.black.opacity(0.1)
        }
        return Color.black.opacity(0.48)
    }

    private var glassBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .fill(
                        usesLightTabChrome
                            ? Color.white.opacity(0.72)
                            : Color(hex: "#1C1C1E").opacity(0.82)
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        usesLightTabChrome
                            ? Color.black.opacity(0.06)
                            : Color.white.opacity(0.14),
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
                consumePendingDeepLink()
                appState.refreshWidgets(context: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    runMissedWorkoutDetection()
                    rescheduleNotifications()
                    appState.refreshWidgets(context: modelContext)
                }
                guard appState.canUseCloudSync else { return }
                if newPhase == .active {
                    Task {
                        await syncService.sync(
                            modelContext: modelContext,
                            userId: appState.authenticatedUserId,
                            mode: .incremental,
                            scope: .all
                        )
                    }
                }
            }
            .onChange(of: appState.pendingDeepLinkTab) { _, _ in
                consumePendingDeepLink()
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

    private func consumePendingDeepLink() {
        guard let tab = appState.pendingDeepLinkTab else { return }
        tabBarState.selectTab(tab)
        appState.clearPendingDeepLinkTab()
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
