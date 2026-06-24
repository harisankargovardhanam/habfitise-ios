import SwiftUI
import SwiftData
import UIKit

struct HabitsView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let userId = appState.authenticatedUserId {
                HabitsContentView(userId: userId)
            } else {
                ProgressView()
                    .tint(theme.colors.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.background.ignoresSafeArea())
            }
        }
    }
}

struct HabitsContentView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(SyncService.self) private var syncService
    let userId: String
    var showsBackButton = false

    @Environment(\.modelContext) private var modelContext
    @Environment(TabBarState.self) private var tabBarState
    @State private var viewModel = HabitsViewModel()

    @Query private var habits: [Habit]
    @Query private var weekCompletions: [HabitCompletion]
    @Query private var waterLogs: [WaterLog]
    @Query private var waterGoals: [WaterGoal]

    init(userId: String, showsBackButton: Bool = false) {
        let normalizedUserId = userId.lowercased()
        self.userId = normalizedUserId
        self.showsBackButton = showsBackButton

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = Self.mondayStart(for: today, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? today.addingTimeInterval(604_800)

        let todayStart = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart.addingTimeInterval(86_400)

        _habits = Query(
            filter: #Predicate<Habit> { habit in
                habit.userId == normalizedUserId && habit.isActive
            },
            sort: [SortDescriptor(\.createdAt)]
        )

        _weekCompletions = Query(
            filter: #Predicate<HabitCompletion> { completion in
                completion.userId == normalizedUserId
                    && completion.completedDate >= weekStart
                    && completion.completedDate < weekEnd
            },
            sort: [SortDescriptor(\.completedDate, order: .reverse)]
        )

        _waterLogs = Query(
            filter: #Predicate<WaterLog> { log in
                log.userId == normalizedUserId
                    && log.loggedAt >= todayStart
                    && log.loggedAt < tomorrow
            },
            sort: [SortDescriptor(\.loggedAt, order: .reverse)]
        )

        _waterGoals = Query(
            filter: #Predicate<WaterGoal> { goal in
                goal.userId == normalizedUserId
            }
        )
    }

    var body: some View {
        habitsScreenContent
            .background(theme.colors.background.ignoresSafeArea())
            .modifier(HabitsScreenChromeModifier(
                showsBackButton: showsBackButton,
                onAdd: { viewModel.showAddHabit = true }
            ))
            .onAppear {
                tabBarState.resetScrollState()
                syncViewModel()
            }
            .onChange(of: habits.map(\.id)) { _, _ in syncViewModel() }
            .onChange(of: weekCompletions.map(\.id)) { _, _ in syncViewModel() }
            .onChange(of: waterLogs.map(\.amountMl)) { _, _ in syncViewModel() }
            .onChange(of: waterGoals.first?.dailyGoalMl) { _, _ in syncViewModel() }
            .sheet(isPresented: $viewModel.showAddHabit) {
                AddHabitSheet(userId: userId) {
                    syncViewModel()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("Delete habit?", isPresented: $viewModel.showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    HabfitiseHaptics.destructive()
                    if let habit = viewModel.habitPendingDelete {
                        viewModel.deleteHabit(habit, context: modelContext, syncService: syncService)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.habitPendingDelete = nil
                }
            } message: {
                if let habit = viewModel.habitPendingDelete {
                    Text("“\(habit.name)” and its history will be removed permanently.")
                }
            }
    }

    private var habitsScreenContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: HabfitiseSpacing.md) {
                habitsHeader
                    .habfitiseStaggeredAppear(index: 0)

                LazyVStack(spacing: 12) {
                    AddHabitRow {
                        viewModel.showAddHabit = true
                    }

                    if !viewModel.hasLoadedHabits {
                        HabitListSkeleton()
                    } else if habits.isEmpty {
                        HabfitiseEmptyState(
                            icon: "leaf.fill",
                            title: "No habits yet",
                            subtitle: "Tap + to add your first"
                        )
                    } else {
                        ForEach(habits) { habit in
                            HabitCard(
                                habit: habit,
                                days: viewModel.weekDays(for: habit.id, completions: weekCompletions),
                                streak: viewModel.streak(for: habit.id),
                                isCompletedToday: viewModel.isCompletedToday(
                                    habitId: habit.id,
                                    completions: weekCompletions
                                ),
                                onComplete: {
                                    if viewModel.completeHabit(
                                        habit,
                                        userId: userId,
                                        completions: weekCompletions,
                                        context: modelContext,
                                        syncService: syncService
                                    ) != nil {
                                        HabfitiseHaptics.milestone()
                                    }
                                },
                                onUndo: {
                                    viewModel.undoHabitToday(
                                        habit,
                                        completions: weekCompletions,
                                        context: modelContext,
                                        syncService: syncService
                                    )
                                },
                                onDelete: {
                                    viewModel.requestDelete(habit)
                                }
                            )
                        }
                    }

                    WaterIntakeCard(
                        waterToday: viewModel.waterTodayML,
                        waterGoal: viewModel.waterGoalML,
                        filledCups: viewModel.filledWaterCups(for: HabitsViewModel.homeWaterCupCount),
                        cupCount: HabitsViewModel.homeWaterCupCount,
                        animatingCupIndex: viewModel.animatingCupIndex,
                        celebrationActive: viewModel.waterCelebrationActive,
                        nextReminderMinutes: viewModel.nextReminderMinutes,
                        onCupTap: { index in
                            viewModel.addWater(
                                at: index,
                                userId: userId,
                                context: modelContext,
                                syncService: syncService,
                                cupCount: HabitsViewModel.homeWaterCupCount
                            )
                            runWaterCelebrationIfNeeded()
                        },
                        onAddWater: {
                            viewModel.addWaterLog(
                                amountMl: AppConstants.Water.dropLogML,
                                userId: userId,
                                context: modelContext,
                                syncService: syncService
                            )
                        }
                    )
                }
                .habfitiseStaggeredAppear(index: 1)
                .padding(.horizontal, HabfitiseSpacing.lg)
            }
            .padding(.bottom, TabBarLayout.tabBarScrollInsetWithFoodLog)
            .reportScrollOffsetToTabBar()
        }
        .contentMargins(.bottom, TabBarLayout.scrollBreathingRoom, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
        .cloudRefreshable(scope: .habits, perform: syncViewModel)
    }

    // MARK: - Header

    private var habitsHeader: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            if !showsBackButton {
                HabfitiseTabPageHeader(title: "Habits") {
                    HabitsAddButton {
                        viewModel.showAddHabit = true
                    }
                }
            }

            summaryRow
                .padding(.horizontal, HabfitiseSpacing.lg)
        }
    }

    private var summaryRow: some View {
        HStack {
            Text("\(HabfitiseCopy.counted(viewModel.activeHabitCount(from: habits), "active habit", plural: "active habits"))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary)

            Spacer()

            HStack(spacing: 4) {
                Text("🔥")
                Text("\(HabfitiseCopy.counted(viewModel.aggregateStreak(from: habits), "day")) streak")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
            }
        }
    }

    // MARK: - Helpers

    private func runWaterCelebrationIfNeeded() {
        guard viewModel.shouldCelebrateWaterFill() else { return }

        viewModel.beginWaterCelebration()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            for index in 0..<HabitsViewModel.homeWaterCupCount {
                viewModel.animatingCupIndex = index
                try? await Task.sleep(for: .milliseconds(60))
            }
            viewModel.animatingCupIndex = nil

            try? await Task.sleep(for: .milliseconds(600))
            viewModel.endWaterCelebration()
        }
    }

    private func syncViewModel() {
        viewModel.bind(
            habits: habits,
            completions: weekCompletions,
            waterLogs: waterLogs,
            waterGoal: waterGoals.first
        )
        WidgetDataPublisher.refresh(context: modelContext, userId: userId)
    }

    private static func mondayStart(for date: Date, calendar: Calendar) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: date)) ?? date
    }
}

private struct HabitsScreenChromeModifier: ViewModifier {
    let showsBackButton: Bool
    let onAdd: () -> Void

    func body(content: Content) -> some View {
        if showsBackButton {
            content
                .habfitisePushedScreen(title: "Habits") {
                    HabitsAddButton(action: onAdd)
                }
        } else {
            content
                .habfitiseTabScreen(immersiveHeader: true)
        }
    }
}

#if DEBUG
struct HabitsView_Previews: PreviewProvider {
    static var previews: some View {
        HabitsContentView(userId: "preview-user")
            .environment(AppState())
            .environment(TabBarState())
            .modelContainer(try! SwiftDataStack.makeContainer(inMemory: true))
            .environment(ThemeManager())
    }
}
#endif
