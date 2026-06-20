import SwiftUI

struct LiquidGlassTabBar: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(TabBarState.self) private var tabBarState

    private let edgeInset: CGFloat = 16

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: tabBarState.showsLabels ? 0 : HabfitiseSpacing.lg) {
                ForEach(MainTab.allCases) { tab in
                    tabItem(tab)
                }
            }
            .padding(.horizontal, tabBarState.showsLabels ? HabfitiseSpacing.lg : HabfitiseSpacing.md)
            .padding(.vertical, HabfitiseSpacing.md)
            .frame(maxWidth: tabBarState.pillMaxWidth)
            .background { pillBackground }
            .clipShape(RoundedRectangle(cornerRadius: HabfitiseRadius.full, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, edgeInset)
        .padding(.bottom, edgeInset)
        .animation(HabfitiseAnimation.tabTransition, value: tabBarState.isVisible)
        .animation(HabfitiseAnimation.interactive, value: tabBarState.activeTab)
    }

    @ViewBuilder
    private func tabItem(_ tab: MainTab) -> some View {
        let isActive = tabBarState.activeTab == tab

        Button {
            tabBarState.selectTab(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .habfitiseTabBounce(isActive: isActive)

                if isActive, tabBarState.showsLabels {
                    Text(tab.title)
                        .font(HabfitiseTypography.caption)
                        .fontWeight(.semibold)
                        .opacity(tabBarState.labelOpacity)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .foregroundStyle(
                isActive
                    ? theme.colors.accentGreen
                    : theme.colors.textTertiary
            )
            .frame(maxWidth: tabBarState.showsLabels ? .infinity : nil)
            .frame(minWidth: tabBarState.showsLabels ? nil : 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.96))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var pillBackground: some View {
        RoundedRectangle(cornerRadius: HabfitiseRadius.full, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: HabfitiseRadius.full, style: .continuous)
                    .fill(theme.colors.cardBackground.opacity(0.92))
            }
            .overlay {
                RoundedRectangle(cornerRadius: HabfitiseRadius.full, style: .continuous)
                    .strokeBorder(theme.colors.cardBorder, lineWidth: 1)
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
