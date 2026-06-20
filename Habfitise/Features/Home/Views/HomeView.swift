import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Group {
            if let userId = appState.authenticatedUserId {
                HomeContentView(userId: userId)
            } else {
                ProgressView()
                    .tint(BentoDashboardTheme.cobalt)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BentoDashboardTheme.cobalt.ignoresSafeArea())
            }
        }
    }
}

struct HomeContentView: View {
    let userId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(TabBarState.self) private var tabBarState
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService
    @Environment(ThemeManager.self) private var themeManager

    @State private var viewModel = HomeViewModel()
    @State private var metricsPeriod: BentoMetricsPeriod = .week
    @State private var builderRoute: WorkoutBuilderRoute?
    @State private var detailSessionRoute: HomeSessionRoute?
    @State private var showHabits = false
    @State private var showTasks = false
    @State private var showProfile = false
    @State private var showAddTask = false

    @Bindable private var notificationBridge = WorkoutNotificationBridge.shared

    @Query private var habits: [Habit]
    @Query private var tasks: [TaskRecord]
    @Query private var waterLogs: [WaterLog]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query private var todaySessions: [WorkoutSession]
    @Query private var recentSessions: [WorkoutSession]
    @Query private var pendingMissedWorkouts: [MissedWorkout]
    @Query private var profiles: [UserProfile]
    @Query private var waterGoals: [WaterGoal]

    init(userId: String) {
        self.userId = userId

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let monthAgo = calendar.date(byAdding: .day, value: -35, to: today) ?? today.addingTimeInterval(-35 * 86_400)

        _habits = Query(
            filter: #Predicate<Habit> { habit in
                habit.userId == userId && habit.isActive
            },
            sort: [SortDescriptor(\.createdAt)]
        )

        _tasks = Query(
            filter: #Predicate<TaskRecord> { task in
                task.userId == userId && task.isComplete == false
            },
            sort: [SortDescriptor(\.dueDate)]
        )

        _waterLogs = Query(
            filter: #Predicate<WaterLog> { log in
                log.userId == userId && log.loggedAt >= today && log.loggedAt < tomorrow
            },
            sort: [SortDescriptor(\.loggedAt, order: .reverse)]
        )

        _workoutTemplates = Query(
            filter: #Predicate<WorkoutTemplate> { template in
                template.userId == userId
            },
            sort: [SortDescriptor(\.lastPerformedAt, order: .reverse)]
        )

        _todaySessions = Query(
            filter: #Predicate<WorkoutSession> { session in
                session.userId == userId
                    && session.startedAt >= today
                    && session.startedAt < tomorrow
            },
            sort: [SortDescriptor(\.startedAt)]
        )

        _recentSessions = Query(
            filter: #Predicate<WorkoutSession> { session in
                session.userId == userId && session.startedAt >= monthAgo
            },
            sort: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        _pendingMissedWorkouts = Query(
            filter: #Predicate<MissedWorkout> { missed in
                missed.userId == userId
            },
            sort: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )

        _profiles = Query(
            filter: #Predicate<UserProfile> { profile in
                profile.userId == userId
            }
        )

        _waterGoals = Query(
            filter: #Predicate<WaterGoal> { goal in
                goal.userId == userId
            }
        )
    }

    var body: some View {
        bentoDashboard
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                tabBarState.resetScrollState()
                syncViewModel()
            }
            .onChange(of: habits.map(\.id)) { _, _ in syncViewModel() }
            .onChange(of: tasks.map(\.id)) { _, _ in syncViewModel() }
            .onChange(of: waterLogs.map(\.amountMl)) { _, _ in syncViewModel() }
            .onChange(of: workoutTemplates.map(\.id)) { _, _ in syncViewModel() }
            .onChange(of: todaySessions.map(\.id)) { _, _ in syncViewModel() }
            .onChange(of: recentSessions.map(\.id)) { _, _ in syncViewModel() }
            .onChange(of: notificationBridge.pendingBuilder?.workoutType) { _, _ in
                consumeNotificationBuilder()
            }
            .modifier(HomePresentationModifier(
                userId: userId,
                habits: habits,
                builderRoute: $builderRoute,
                detailSessionRoute: $detailSessionRoute,
                showHabits: $showHabits,
                showTasks: $showTasks,
                showProfile: $showProfile,
                showAddTask: $showAddTask,
                onSync: syncViewModel
            ))
    }

    private var bentoDashboard: some View {
        BentoCollapsingDashboard(
            greeting: viewModel.greeting,
            primaryValue: "\(viewModel.streakStats.weeklyCompleted)",
            primaryLabel: "Workouts this week",
            secondaryValue: "\(viewModel.streakStats.dayStreak)d",
            secondaryLabel: "Day streak",
            profileDisplayName: profileDisplayName,
            onProfileTap: { showProfile = true }
        ) {
            VStack(spacing: HabfitiseSpacing.xl) {
                BentoPeriodPicker(selection: $metricsPeriod)
                    .habfitiseStaggeredAppear(index: 1)

                BentoCapsuleChart(bars: activityBars)
                    .habfitiseStaggeredAppear(index: 2)

                VStack(spacing: HabfitiseSpacing.md) {
                    bentoWorkoutCell
                        .habfitiseStaggeredAppear(index: 3)

                    BentoTwinColumnRow {
                        bentoHabitsCell
                    } right: {
                        bentoTasksCell
                    }
                    .habfitiseStaggeredAppear(index: 4)

                    BentoTwinColumnRow {
                        bentoWaterCell
                    } right: {
                        bentoStreakCell
                    }
                    .habfitiseStaggeredAppear(index: 5)
                }

                BentoCell {
                    BentoMoodSelector(viewModel: viewModel, userId: userId)
                }
                .habfitiseStaggeredAppear(index: 6)
            }
        }
    }

    // MARK: - Bento cells

    private var bentoWorkoutCell: some View {
        BentoCell {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                BentoSectionTitle(title: "Today's Workout")

                ForEach(pendingMissedBannerItems, id: \.missed.id) { item in
                    MissedWorkoutBanner(
                        templateName: item.template.name,
                        scheduledDate: item.missed.scheduledDate,
                        onPushTomorrow: {
                            MissedWorkoutService.shared.resolve(
                                missed: item.missed,
                                template: item.template,
                                response: .pushTomorrow,
                                context: modelContext
                            )
                        },
                        onSkip: {
                            MissedWorkoutService.shared.resolve(
                                missed: item.missed,
                                template: item.template,
                                response: .skip,
                                context: modelContext
                            )
                        }
                    )
                }

                if viewModel.hasLoadedWorkoutSection {
                    homeWorkoutCard
                } else {
                    WorkoutCardSkeleton()
                }
            }
        }
    }

    private var bentoHabitsCell: some View {
        BentoCell {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                BentoSectionTitle(title: "Habits", actionTitle: "All") {
                    showHabits = true
                }

                if viewModel.habitItems.isEmpty {
                    Text("No habits yet")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BentoDashboardTheme.label)
                } else {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
                        BentoMetricLabel(
                            value: "\(viewModel.habitItems.filter(\.isCompleted).count)/\(viewModel.habitItems.count)",
                            label: "Completed today"
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: HabfitiseSpacing.sm) {
                                ForEach(viewModel.habitItems.prefix(4)) { item in
                                    BentoHabitChip(item: item)
                                }
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var bentoTasksCell: some View {
        BentoCell {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                BentoSectionTitle(title: "Tasks", actionTitle: "All") {
                    showTasks = true
                }

                if viewModel.taskItems.isEmpty {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
                        Text("Nothing due")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(BentoDashboardTheme.label)

                        Button {
                            showAddTask = true
                        } label: {
                            Label("Add task", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(BentoDashboardTheme.cobalt)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    BentoMetricLabel(
                        value: "\(viewModel.taskItems.count)",
                        label: "Open tasks"
                    )

                    ForEach(viewModel.taskItems.prefix(2)) { task in
                        BentoTaskRow(task: task)
                    }
                }
            }
        }
    }

    private var bentoWaterCell: some View {
        BentoCell {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                BentoSectionTitle(title: "Water")

                BentoMetricLabel(
                    value: "\(Int((Double(viewModel.waterTodayML) / Double(max(viewModel.waterGoalML, 1))) * 100))%",
                    label: "Daily goal"
                )

                BentoWaterProgress(current: viewModel.waterTodayML, goal: viewModel.waterGoalML)

                BentoWaterDropRow(filledCount: viewModel.filledWaterDrops) {
                    viewModel.logWaterDrop(userId: userId, context: modelContext)
                }
            }
        }
    }

    private var bentoStreakCell: some View {
        BentoCell {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                BentoSectionTitle(title: "Streak")

                HStack(spacing: HabfitiseSpacing.md) {
                    BentoWeeklyRing(
                        workoutsThisWeek: viewModel.streakStats.weeklyCompleted,
                        total: viewModel.streakStats.weeklyTotal
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(viewModel.streakStats.sessionsLogged)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(BentoDashboardTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Sessions logged")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(BentoDashboardTheme.label)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(viewModel.streakStats.habitsDone) habits")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(BentoDashboardTheme.cobalt)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var homeWorkoutCard: some View {
        switch viewModel.workoutCard.mode {
        case .completed:
            Button {
                if let sessionId = viewModel.workoutCard.sessionId,
                   let session = todaySessions.first(where: { $0.id == sessionId }) {
                    detailSessionRoute = HomeSessionRoute(session: session)
                }
            } label: {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                    Text(viewModel.workoutCard.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(BentoDashboardTheme.ink)

                    BentoWorkoutChipRow(chips: viewModel.workoutCard.chips)

                    if let duration = viewModel.workoutCard.summaryDuration,
                       let volume = viewModel.workoutCard.summaryVolume {
                        HStack(spacing: HabfitiseSpacing.lg) {
                            Label(duration, systemImage: "clock")
                            Label(volume, systemImage: "scalemass")
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BentoDashboardTheme.label)
                    }

                    Text("View session details")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BentoDashboardTheme.cobalt)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

        case .scheduled:
            Text(viewModel.workoutCard.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.ink)

            BentoWorkoutChipRow(chips: viewModel.workoutCard.chips)

            bentoPrimaryButton(title: "Start Workout") {
                openScheduledWorkout()
            }

        case .quickStart:
            Text("Quick Start")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.ink)

            Text("Pick a workout type below")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.label)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HabfitiseSpacing.sm) {
                homeQuickStartButton(type: .weights, icon: "dumbbell.fill", label: "Weights")
                homeQuickStartButton(type: .cardio, icon: "figure.run", label: "Cardio")
                homeQuickStartButton(type: .bodyweight, icon: "figure.jumprope", label: "Bodyweight")
                homeQuickStartButton(type: .hiit, icon: "bolt.heart.fill", label: "HIIT")
            }
        }
    }

    // MARK: - Helpers

    private var activityBars: [BentoActivityBar] {
        BentoActivityBuilder.bars(
            period: metricsPeriod,
            sessions: recentSessions,
            habitCompletions: viewModel.streakStats.habitsDone
        )
    }

    private var pendingMissedBannerItems: [(missed: MissedWorkout, template: WorkoutTemplate)] {
        pendingMissedWorkouts
            .filter { $0.action == .pending }
            .compactMap { missed in
            guard let template = workoutTemplates.first(where: { $0.id == missed.templateId }) else { return nil }
            return (missed, template)
        }
    }

    private var profileDisplayName: String? {
        guard let name = profiles.first?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        return name
    }

    private func syncViewModel() {
        viewModel.bind(
            userId: userId,
            habits: habits,
            tasks: tasks,
            waterLogs: waterLogs,
            workoutTemplates: workoutTemplates,
            todaySessions: todaySessions,
            profile: profiles.first,
            waterGoal: waterGoals.first,
            context: modelContext
        )
    }

    private func openScheduledWorkout() {
        guard let type = viewModel.workoutCard.workoutType else { return }
        let template = viewModel.workoutCard.templateId.flatMap { id in
            workoutTemplates.first(where: { $0.id == id })
        }
        builderRoute = WorkoutBuilderRoute(type: type, template: template)
    }

    private func openQuickStart(type: WorkoutType) {
        builderRoute = WorkoutBuilderRoute(type: type, template: nil)
    }

    private func consumeNotificationBuilder() {
        guard let pending = notificationBridge.consumePendingBuilder() else { return }
        let template = pending.templateId.flatMap { id in
            workoutTemplates.first(where: { $0.id == id })
        }
        builderRoute = WorkoutBuilderRoute(type: pending.workoutType, template: template)
    }

    private func homeQuickStartButton(type: WorkoutType, icon: String, label: String) -> some View {
        Button {
            openQuickStart(type: type)
        } label: {
            VStack(spacing: HabfitiseSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(BentoDashboardTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HabfitiseSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: BentoDashboardTheme.cardRadius, style: .continuous)
                    .fill(BentoDashboardTheme.softFill)
            )
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.97))
    }

    private func bentoPrimaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(BentoDashboardTheme.cobalt)
                )
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.98))
    }
}

// MARK: - Bento micro-components

private struct BentoHabitChip: View {
    let item: HomeHabitChipItem

    var body: some View {
        HStack(spacing: 4) {
            if item.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
            Text(item.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(item.isCompleted ? BentoDashboardTheme.cobalt : BentoDashboardTheme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(item.isCompleted ? BentoDashboardTheme.cobalt.opacity(0.12) : BentoDashboardTheme.softFill)
        )
    }
}

private struct BentoTaskRow: View {
    let task: HomeTaskItem

    var body: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(task.isComplete ? BentoDashboardTheme.cobalt : BentoDashboardTheme.label)

            Text(task.title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}

private struct BentoWorkoutChipRow: View {
    let chips: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HabfitiseSpacing.sm) {
                ForEach(chips, id: \.self) { chip in
                    BentoPillBadge(text: chip)
                }
            }
        }
    }
}

private struct BentoWeeklyRing: View {
    let workoutsThisWeek: Int
    let total: Int

    @State private var ringProgress: Double = 0

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(total), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(BentoDashboardTheme.softFill, lineWidth: 5)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    BentoDashboardTheme.cobalt,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(workoutsThisWeek)/\(total)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.ink)
        }
        .frame(width: 64, height: 64)
        .onAppear {
            withAnimation(.spring(response: 0.8)) {
                ringProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.8)) {
                ringProgress = newValue
            }
        }
    }
}

private struct HomeSessionRoute: Identifiable {
    let session: WorkoutSession
    var id: UUID { session.id }
}

private struct HomePresentationModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService
    @Environment(ThemeManager.self) private var themeManager
    @Environment(TabBarState.self) private var tabBarState

    let userId: String
    let habits: [Habit]
    @Binding var builderRoute: WorkoutBuilderRoute?
    @Binding var detailSessionRoute: HomeSessionRoute?
    @Binding var showHabits: Bool
    @Binding var showTasks: Bool
    @Binding var showProfile: Bool
    @Binding var showAddTask: Bool
    let onSync: () -> Void

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $builderRoute) { route in
                WorkoutBuilderView(type: route.type, template: route.template)
                    .environment(appState)
                    .environment(syncService)
                    .environment(themeManager)
            }
            .sheet(item: $detailSessionRoute) { route in
                NavigationStack {
                    SessionDetailView(session: route.session, showsDoneButton: true)
                        .environment(themeManager)
                }
            }
            .fullScreenCover(isPresented: $showHabits) {
                HabitsContentView(userId: userId, showsBackButton: true)
                    .environment(appState)
                    .environment(tabBarState)
            }
            .fullScreenCover(isPresented: $showTasks) {
                TasksContentView(userId: userId, showsBackButton: true)
                    .environment(appState)
                    .environment(tabBarState)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView(userId: userId)
                    .environment(appState)
                    .environment(themeManager)
                    .preferredColorScheme(themeManager.preferredColorScheme)
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskSheet(userId: userId, habits: habits, onSave: onSync)
            }
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeContentView(userId: "preview-user")
            .environment(AppState())
            .environment(TabBarState())
            .environment(ThemeManager())
            .modelContainer(try! SwiftDataStack.makeContainer(inMemory: true))
    }
}
#endif
