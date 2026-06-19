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
                    .tint(themeManager.colors.textOnBackground)
                    .habfitiseGreenBackground()
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
    @Query private var pendingMissedWorkouts: [MissedWorkout]
    @Query private var profiles: [UserProfile]
    @Query private var waterGoals: [WaterGoal]

    private let cardOverlap: CGFloat = HabfitiseRadius.xl

    init(userId: String) {
        self.userId = userId

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)

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
        HomePhaseScrollLayout(
            cardOverlap: cardOverlap,
            fullHeaderHeight: 300,
            maxHeaderCollapse: 118
        ) {
            greenHeader
        } content: {
            cardContent
                .reportScrollOffsetToTabBar()
        }
        .background {
            ZStack(alignment: .top) {
                themeManager.colors.cardBackground
                themeManager.colors.headerBackground
                    .frame(height: 320)
                    .ignoresSafeArea(edges: .top)
            }
            .ignoresSafeArea()
        }
        .habfitiseTabScreen(statusBarMatchesHeader: true)
        .onAppear {
            tabBarState.resetScrollState()
            syncViewModel()
        }
        .onChange(of: habits.map(\.id)) { _, _ in syncViewModel() }
        .onChange(of: tasks.map(\.id)) { _, _ in syncViewModel() }
        .onChange(of: waterLogs.map(\.amountMl)) { _, _ in syncViewModel() }
        .onChange(of: workoutTemplates.map(\.id)) { _, _ in syncViewModel() }
        .onChange(of: todaySessions.map(\.id)) { _, _ in syncViewModel() }
        .onChange(of: notificationBridge.pendingBuilder?.workoutType) { _, _ in
            consumeNotificationBuilder()
        }
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
            AddTaskSheet(userId: userId, habits: habits) {
                syncViewModel()
            }
        }
    }

    // MARK: - Green Header

    private var greenHeader: some View {
        HomeGreenHeader(
            greeting: viewModel.greeting,
            workoutTitle: viewModel.workoutTitle,
            memberSince: viewModel.memberSinceFormatted,
            profileDisplayName: profileDisplayName,
            cardOverlap: cardOverlap,
            viewModel: viewModel,
            userId: userId,
            onProfileTap: { showProfile = true }
        )
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            workoutSection
            habitsSection
            tasksSection
            waterSection
            streakSection
        }
        .padding(HabfitiseSpacing.xxl)
        .padding(.bottom, HabfitiseSpacing.xxxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.colors.cardBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: HabfitiseRadius.xl,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: HabfitiseRadius.xl,
                style: .continuous
            )
        )
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            HabfitiseSectionLabel(text: "Today's Workout")

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
                        .foregroundStyle(themeManager.colors.textPrimary)

                    WorkoutChipRow(chips: viewModel.workoutCard.chips)

                    if let duration = viewModel.workoutCard.summaryDuration,
                       let volume = viewModel.workoutCard.summaryVolume {
                        HStack(spacing: HabfitiseSpacing.lg) {
                            Label(duration, systemImage: "clock")
                            Label(volume, systemImage: "scalemass")
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.colors.textSecondary)
                    }

                    Text("View session details")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.colors.accentGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

        case .scheduled:
            Text(viewModel.workoutCard.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.colors.textPrimary)

            WorkoutChipRow(chips: viewModel.workoutCard.chips)

            HabfitisePrimaryButton(title: "Start Workout") {
                openScheduledWorkout()
            }

        case .quickStart:
            Text("Quick Start")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.colors.textPrimary)

            Text("Pick a workout type below")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.colors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HabfitiseSpacing.sm) {
                homeQuickStartButton(type: .weights, icon: "dumbbell.fill", label: "Weights")
                homeQuickStartButton(type: .cardio, icon: "figure.run", label: "Cardio")
                homeQuickStartButton(type: .bodyweight, icon: "figure.jumprope", label: "Bodyweight")
                homeQuickStartButton(type: .hiit, icon: "bolt.heart.fill", label: "HIIT")
            }
        }
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            SectionHeaderRow(title: "Habits", trailingActionTitle: "See all") {
                showHabits = true
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HabfitiseSpacing.sm) {
                    ForEach(viewModel.habitItems) { item in
                        HabitCompletionChip(item: item)
                    }
                }
            }
        }
        .padding(.top, HabfitiseSpacing.lg)
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            SectionHeaderRow(title: "Tasks", trailingActionTitle: "See all") {
                showTasks = true
            }

            if viewModel.taskItems.isEmpty {
                HStack {
                    Text("No tasks due today")
                        .font(HabfitiseTypography.subheadline)
                        .foregroundStyle(themeManager.colors.textSecondary)

                    Spacer()

                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(themeManager.colors.textTertiary.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(viewModel.taskItems) { task in
                    TaskRowCompact(task: task)
                }
            }
        }
        .padding(.top, HabfitiseSpacing.lg)
    }

    private var waterSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            SectionHeaderRow(
                title: "Water Today",
                trailingTitle: "\(viewModel.waterTodayML) / \(viewModel.waterGoalML) ml"
            )

            WaterProgressBar(current: viewModel.waterTodayML, goal: viewModel.waterGoalML)

            WaterCupRow(filledCount: viewModel.filledWaterDrops) {
                viewModel.logWaterDrop(userId: userId, context: modelContext)
            }
        }
        .padding(.top, HabfitiseSpacing.lg)
    }

    private var streakSection: some View {
        HStack(alignment: .center, spacing: HabfitiseSpacing.lg) {
            WeeklyRingView(
                workoutsThisWeek: viewModel.streakStats.weeklyCompleted,
                total: viewModel.streakStats.weeklyTotal
            )

            VStack(alignment: .leading, spacing: HabfitiseSpacing.xs) {
                Text("🔥 \(viewModel.streakStats.dayStreak) day streak")
                Text("\(viewModel.streakStats.sessionsLogged) sessions logged")
                Text("\(viewModel.streakStats.habitsDone) habits done")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(themeManager.colors.textSecondary)
        }
        .padding(.top, HabfitiseSpacing.lg)
    }

    // MARK: - Helpers

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
            .foregroundStyle(themeManager.colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HabfitiseSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: HabfitiseRadius.md, style: .continuous)
                    .fill(themeManager.colors.fieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: HabfitiseRadius.md, style: .continuous)
                            .stroke(themeManager.colors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeSessionRoute: Identifiable {
    let session: WorkoutSession
    var id: UUID { session.id }
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
