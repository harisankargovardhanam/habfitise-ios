import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let userId = appState.authenticatedUserId {
                ProgressContentView(userId: userId)
            } else {
                ProgressView()
                    .tint(theme.colors.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.background.ignoresSafeArea())
            }
        }
    }
}

struct ProgressContentView: View {
    @Environment(ThemeManager.self) private var theme
    let userId: String

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProgressViewModel()

    @Query private var sessions: [WorkoutSession]
    @Query private var sets: [ExerciseSet]
    @Query private var habits: [Habit]
    @Query private var completions: [HabitCompletion]
    @Query private var tasks: [TaskRecord]
    @Query private var waterLogs: [WaterLog]
    @Query private var waterGoals: [WaterGoal]
    @Query private var bodyWeightEntries: [BodyWeightEntry]
    @Query private var profiles: [UserProfile]

    init(userId: String) {
        self.userId = userId

        _sessions = Query(
            filter: #Predicate<WorkoutSession> { $0.userId == userId },
            sort: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        _sets = Query(
            filter: #Predicate<ExerciseSet> { $0.userId == userId },
            sort: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        _habits = Query(
            filter: #Predicate<Habit> { $0.userId == userId && $0.isActive },
            sort: [SortDescriptor(\.createdAt)]
        )
        _completions = Query(
            filter: #Predicate<HabitCompletion> { $0.userId == userId },
            sort: [SortDescriptor(\.completedDate, order: .reverse)]
        )
        _tasks = Query(
            filter: #Predicate<TaskRecord> { $0.userId == userId },
            sort: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        _waterLogs = Query(
            filter: #Predicate<WaterLog> { $0.userId == userId },
            sort: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        _waterGoals = Query(
            filter: #Predicate<WaterGoal> { $0.userId == userId }
        )
        _bodyWeightEntries = Query(
            filter: #Predicate<BodyWeightEntry> { $0.userId == userId },
            sort: [SortDescriptor(\.loggedAt)]
        )
        _profiles = Query(
            filter: #Predicate<UserProfile> { $0.userId == userId }
        )
    }

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: HabfitiseSpacing.lg) {
                HabfitiseTabPageHeader(title: "Progress")
                    .habfitiseStaggeredAppear(index: 0)

                VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                    if viewModel.workoutCount == 0 && sets.isEmpty {
                        HabfitiseEmptyState(
                            icon: "chart.bar.fill",
                            title: "No progress yet",
                            subtitle: "Start working out to see your progress"
                        )
                        .habfitiseStaggeredAppear(index: 1)
                    } else {
                        progressSections
                    }
                }
                .padding(.horizontal, HabfitiseSpacing.lg)
            }
            .padding(.bottom, TabBarLayout.floatingClearance)
            .reportScrollOffsetToTabBar()
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
        .background(theme.colors.background.ignoresSafeArea())
        .habfitiseTabScreen(immersiveHeader: true)
        .onAppear(perform: syncViewModel)
        .onChange(of: sessions.count) { _, _ in syncViewModel() }
        .onChange(of: sets.count) { _, _ in syncViewModel() }
        .onChange(of: completions.count) { _, _ in syncViewModel() }
        .onChange(of: waterLogs.count) { _, _ in syncViewModel() }
    }

    private var progressSections: some View {
        Group {
            WorkoutStreakCard(stats: WorkoutAnalytics.streakStats(userId: userId, context: modelContext))
                .habfitiseStaggeredAppear(index: 1)

            ProgressStatSummaryCard(
                workoutCount: viewModel.workoutCount,
                habitRate: viewModel.habitCompletionRate,
                tasksDone: viewModel.tasksCompleted
            )
            .habfitiseStaggeredAppear(index: 2)

            ProgressWorkoutMinutesCard(weeklyMinutes: viewModel.weeklyWorkoutMinutes)
                .habfitiseStaggeredAppear(index: 3)

            ProgressPersonalRecordsCard(records: viewModel.personalRecords)
                .habfitiseStaggeredAppear(index: 4)

            if !bodyWeightEntries.isEmpty {
                BodyWeightCard(
                    entries: bodyWeightEntries,
                    targetWeightKg: profile?.targetWeightKg ?? 0,
                    startWeightKg: bodyWeightEntries.first?.weightKg
                )
                .habfitiseStaggeredAppear(index: 5)
            }

            ProgressHabitHeatmapCard(
                cells: viewModel.heatmapCells,
                isPro: appState.isPro,
                onUpgrade: { appState.requireUpgrade(for: .advancedAnalytics) }
            )
            .habfitiseStaggeredAppear(index: bodyWeightEntries.isEmpty ? 5 : 6)

            ProgressWaterWeekCard(
                days: viewModel.waterWeekDays,
                dailyAverage: viewModel.waterDailyAverage,
                goalMl: viewModel.waterGoalML
            )
            .habfitiseStaggeredAppear(index: bodyWeightEntries.isEmpty ? 6 : 7)

            ProgressExportRow(exportURL: exportURL)
                .habfitiseStaggeredAppear(index: bodyWeightEntries.isEmpty ? 7 : 8)
        }
    }

    private var exportURL: URL {
        viewModel.exportFileURL(
            sessions: sessions,
            sets: sets,
            habits: habits,
            completions: completions,
            tasks: tasks,
            waterLogs: waterLogs
        )
    }

    private func syncViewModel() {
        viewModel.bind(
            userId: userId,
            sessions: sessions,
            sets: sets,
            habits: habits,
            completions: completions,
            tasks: tasks,
            waterLogs: waterLogs,
            waterGoal: waterGoals.first,
            isPro: appState.isPro,
            context: modelContext
        )
    }
}

#if DEBUG
struct ProgressDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressContentView(userId: "preview")
            .environment(AppState())
            .environment(TabBarState())
            .environment(ThemeManager())
    }
}
#endif
