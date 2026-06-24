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
                    .tint(themeManager.colors.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.colors.background.ignoresSafeArea())
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
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = HomeViewModel()
    @State private var metricsPeriod: BentoMetricsPeriod = .week
    @State private var builderRoute: WorkoutBuilderRoute?
    @State private var detailSessionRoute: HomeSessionRoute?
    @State private var showProfile = false
    @State private var showAddTask = false
    @State private var showWeightLog = false
    @State private var showStepGoalEditor = false
    @State private var nutritionViewModel = NutritionViewModel()

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
    @Query private var bodyWeightEntries: [BodyWeightEntry]
    @Query private var foodLogs: [FoodLog]

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

        _foodLogs = Query(
            filter: #Predicate<FoodLog> { log in
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

        _bodyWeightEntries = Query(
            filter: #Predicate<BodyWeightEntry> { entry in
                entry.userId == userId
            },
            sort: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
    }

    var body: some View {
        bentoDashboard
            .toolbar(.hidden, for: .navigationBar)
            .modifier(HomeDashboardLifecycleModifier(
                userId: userId,
                habits: habits,
                tasks: tasks,
                waterLogs: waterLogs,
                foodLogs: foodLogs,
                workoutTemplates: workoutTemplates,
                todaySessions: todaySessions,
                recentSessions: recentSessions,
                showWeightLog: $showWeightLog,
                tabBarState: tabBarState,
                notificationBridge: notificationBridge,
                onSync: syncViewModel,
                onWaterSync: syncWaterFromLogs,
                onConsumeNotification: consumeNotificationBuilder
            ))
            .modifier(HomePresentationModifier(
                userId: userId,
                habits: habits,
                builderRoute: $builderRoute,
                detailSessionRoute: $detailSessionRoute,
                showProfile: $showProfile,
                showAddTask: $showAddTask,
                onSync: syncViewModel
            ))
            .onChange(of: appState.isPro) { _, _ in
                syncViewModel()
            }
            .task(id: userId) {
                viewModel.beginHealthMonitoring()
                await viewModel.refreshHealthData(
                    templates: workoutTemplates,
                    todaySessions: todaySessions,
                    habits: habits,
                    tasks: tasks,
                    isPro: appState.isPro
                )
                refreshNutritionSummary()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                scheduleHealthRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthKitStepsDidUpdate)) { _ in
                scheduleHealthRefresh()
            }
            .sheet(isPresented: $showStepGoalEditor) {
                StepGoalEditorSheet(currentGoal: viewModel.healthSnapshot.stepGoal) { goal in
                    Task {
                        await viewModel.updateStepGoal(
                            goal,
                            templates: workoutTemplates,
                            todaySessions: todaySessions,
                            habits: habits,
                            tasks: tasks,
                            isPro: appState.isPro
                        )
                    }
                }
            }
    }

    private func openHabits() {
        tabBarState.selectTab(.habits)
    }

    private func openTasks() {
        tabBarState.selectTab(.tasks)
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
                homeDashboardHeader
                    .habfitiseStaggeredAppear(index: 0)

                homeDashboardCards
                    .habfitiseStaggeredAppear(index: 1)
            }
        }
        .cloudRefreshable(scope: .home, perform: syncViewModel)
    }

    private var homeDashboardCards: some View {
        VStack(spacing: BentoCardStyle.metricGridSpacing) {
            bentoWorkoutCell
            bentoDailyMovementCell
            bentoWaterCell
            bentoNutritionCell
            bentoHabitsCell
            bentoTasksCell
            bentoWeightCell
            bentoEnergyCell
        }
    }

    // MARK: - Bento cells

    private var homeDashboardHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HabfitiseTabPageHeader(title: viewModel.greeting) {
                Button {
                    showProfile = true
                } label: {
                    HomeAvatarView(displayName: profileDisplayName)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open profile")
            }

            if !viewModel.greetingSubtitle.isEmpty {
                Text(viewModel.greetingSubtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            }
        }
    }

    private var bentoDailyMovementCell: some View {
        BentoCardContainer(title: "Daily Movement", accent: .health) {
            BentoDailyMovementCard(
                connectionState: viewModel.healthConnectionState,
                summary: viewModel.activitySummary,
                isPro: appState.isPro,
                onConnect: {
                    Task {
                        await viewModel.connectHealth(isPro: appState.isPro, appState: appState)
                        viewModel.beginHealthMonitoring()
                        scheduleHealthRefresh(force: true)
                    }
                },
                onEditStepGoal: viewModel.healthConnectionState == .connected
                    ? { showStepGoalEditor = true }
                    : nil,
                onOpenHealth: { HealthKitSettingsOpener.openHealthApp() },
                onRefresh: {
                    scheduleHealthRefresh(force: true)
                }
            )
        }
    }

    private var bentoEnergyCell: some View {
        BentoCardContainer(title: "Energy Check-in", accent: .mood) {
            BentoMoodSelector(viewModel: viewModel, userId: userId)
        }
    }

    private var bentoWorkoutCell: some View {
        BentoCardContainer(title: "Today's Workout", accent: .workout) {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
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
        BentoCardContainer(
            title: "Habits",
            accent: .habits,
            actionTitle: "All",
            action: openHabits
        ) {
            if viewModel.habitItems.isEmpty {
                Text("No habits yet")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.colors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                    BentoMetricLabel(
                        value: "\(viewModel.habitItems.filter(\.isCompleted).count)/\(viewModel.habitItems.count)",
                        label: "completed today"
                    )

                    VStack(spacing: HabfitiseSpacing.sm) {
                        ForEach(viewModel.habitItems) { item in
                            BentoHomeStatusRow(
                                title: item.name,
                                isDone: item.isCompleted,
                                style: .habit
                            )
                        }
                    }
                }
            }
        }
    }

    private var bentoTasksCell: some View {
        BentoCardContainer(
            title: "Tasks",
            accent: .tasks,
            actionTitle: "All",
            action: openTasks
        ) {
            if viewModel.taskItems.isEmpty {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                    Text("Nothing due")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.colors.textPrimary)

                    Text("Add a task to keep today on track.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.colors.textSecondary)

                    Button {
                        showAddTask = true
                    } label: {
                        Text("Add task")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.colors.textOnBackground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(themeManager.colors.accentGreen)
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                    BentoMetricLabel(
                        value: "\(viewModel.taskItems.count)",
                        label: "open tasks"
                    )

                    VStack(spacing: HabfitiseSpacing.sm) {
                        ForEach(viewModel.taskItems) { task in
                            BentoHomeStatusRow(
                                title: task.title,
                                isDone: task.isComplete,
                                style: .task
                            )
                        }
                    }
                }
            }
        }
    }

    private var bentoNutritionCell: some View {
        BentoNutritionCard(
            summary: nutritionViewModel.daySummary,
            isPro: appState.isPro,
            onOpenLog: { tabBarState.openFoodLog(addNew: false) },
            onQuickLog: { openNutritionFlow() }
        )
    }

    private func openNutritionFlow() {
        if appState.isPro {
            tabBarState.openFoodLog(addNew: true)
        } else {
            appState.requireUpgrade(for: .aiNutrition)
        }
    }

    private var bentoWaterCell: some View {
        BentoWaterIntakeCard(
            currentML: viewModel.waterTodayML,
            goalML: viewModel.waterGoalML,
            glassVolumeML: viewModel.waterGlassVolumeML,
            filledGlasses: viewModel.filledWaterGlasses,
            glassCount: HomeViewModel.waterGlassCount,
            onQuickAdd: { amountML in
                viewModel.logWaterAmount(amountML, userId: userId, context: modelContext)
            }
        )
    }

    private var bentoWeightCell: some View {
        BentoCardContainer(title: "Weight", accent: .bodyWeight) {
            HStack(alignment: .center, spacing: HabfitiseSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(BentoCardAccent.bodyWeight.focalColor(in: themeManager.colors).opacity(0.14))
                    Image(systemName: "figure.stand")
                        .font(.system(size: 24, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(BentoCardAccent.bodyWeight.focalColor(in: themeManager.colors))
                }
                .frame(width: 56, height: 56)

                Group {
                    if let latest = bodyWeightEntries.first {
                        bentoWeightMetrics(
                            value: String(format: "%.1f", latest.weightKg),
                            subtitle: "Latest entry"
                        )
                    } else if let profileWeight = profiles.first?.weightKg, profileWeight > 0 {
                        bentoWeightMetrics(
                            value: String(format: "%.1f", profileWeight),
                            subtitle: "From profile"
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Log your weight")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(themeManager.colors.textPrimary)
                            Text("Tap to add an entry")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.colors.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textTertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showWeightLog = true
        }
    }

    private func bentoWeightMetrics(value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("kg")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.colors.textSecondary)
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.colors.textSecondary)
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

                    BentoWorkoutChipRow(chips: viewModel.workoutCard.chips)

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

            BentoWorkoutChipRow(chips: viewModel.workoutCard.chips)

            bentoPrimaryButton(title: "Start Workout") {
                openScheduledWorkout()
            }

        case .quickStart:
            Text(viewModel.workoutCard.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.colors.textPrimary)

            if let reason = viewModel.workoutCard.suggestionReason {
                Text(reason)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.colors.textSecondary)
            } else {
                Text("Pick a workout type below")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.colors.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HabfitiseSpacing.sm) {
                homeQuickStartButton(type: .weights, icon: "dumbbell.fill", label: "Weights", highlighted: viewModel.workoutCard.suggestedType == .weights)
                homeQuickStartButton(type: .cardio, icon: "figure.run", label: "Cardio", highlighted: viewModel.workoutCard.suggestedType == .cardio)
                homeQuickStartButton(type: .bodyweight, icon: "figure.jumprope", label: "Bodyweight", highlighted: viewModel.workoutCard.suggestedType == .bodyweight)
                homeQuickStartButton(type: .hiit, icon: "bolt.heart.fill", label: "HIIT", highlighted: viewModel.workoutCard.suggestedType == .hiit)
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

    private func syncWaterFromLogs() {
        viewModel.syncWaterFromLogs(
            waterLogs: waterLogs,
            todaySessions: todaySessions,
            habits: habits,
            tasks: tasks
        )
        publishWidgetSnapshot()
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
        publishWidgetSnapshot()
        refreshNutritionSummary()
        viewModel.applyHealthRefresh(
            templates: workoutTemplates,
            todaySessions: todaySessions,
            habits: habits,
            tasks: tasks
        )
        Task {
            await viewModel.generateDailyPlan(
                appState: appState,
                userId: userId,
                profile: profiles.first
            )
        }
    }

    private func scheduleHealthRefresh(force: Bool = false) {
        viewModel.scheduleAutomaticHealthRefresh(
            templates: workoutTemplates,
            todaySessions: todaySessions,
            habits: habits,
            tasks: tasks,
            isPro: appState.isPro,
            force: force,
            onComplete: { refreshNutritionSummary() }
        )
    }

    private func refreshNutritionSummary() {
        nutritionViewModel.refresh(
            logs: foodLogs,
            profile: profiles.first,
            activeEnergyKcal: viewModel.healthSnapshot.activeEnergyKcal
        )
    }

    private func publishWidgetSnapshot() {
        appState.refreshWidgets(context: modelContext)
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

    private func homeQuickStartButton(type: WorkoutType, icon: String, label: String, highlighted: Bool = false) -> some View {
        Button {
            openQuickStart(type: type)
        } label: {
            VStack(spacing: HabfitiseSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(highlighted ? themeManager.colors.textOnBackground : themeManager.colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HabfitiseSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
                    .fill(highlighted ? themeManager.colors.accentGreen : themeManager.colors.fieldBackground)
            )
            .overlay {
                if highlighted {
                    RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
                        .stroke(themeManager.colors.accentGreen.opacity(0.4), lineWidth: 2)
                }
            }
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
                        .fill(themeManager.colors.accentGreen)
                )
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.98))
    }
}

// MARK: - Bento micro-components

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
    var compact: Bool = false

    @State private var ringProgress: Double = 0
    @Environment(ThemeManager.self) private var theme

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(total), 1)
    }

    private var ringSize: CGFloat { compact ? 44 : 64 }
    private var lineWidth: CGFloat { compact ? 4 : 5 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.colors.trackBackground, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    BentoCardAccent.streak.focalColor(in: theme.colors),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(workoutsThisWeek)/\(total)")
                .font(.system(size: compact ? 11 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)
        }
        .frame(width: ringSize, height: ringSize)
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

private struct HomeDashboardLifecycleModifier: ViewModifier {
    let userId: String
    let habits: [Habit]
    let tasks: [TaskRecord]
    let waterLogs: [WaterLog]
    let foodLogs: [FoodLog]
    let workoutTemplates: [WorkoutTemplate]
    let todaySessions: [WorkoutSession]
    let recentSessions: [WorkoutSession]
    @Binding var showWeightLog: Bool
    let tabBarState: TabBarState
    let notificationBridge: WorkoutNotificationBridge
    let onSync: () -> Void
    let onWaterSync: () -> Void
    let onConsumeNotification: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(HomeDashboardAppearModifier(
                tabBarState: tabBarState,
                onSync: onSync
            ))
            .modifier(HomeDashboardDataSyncModifier(
                habits: habits,
                tasks: tasks,
                waterLogs: waterLogs,
                foodLogs: foodLogs,
                workoutTemplates: workoutTemplates,
                todaySessions: todaySessions,
                recentSessions: recentSessions,
                notificationBridge: notificationBridge,
                onSync: onSync,
                onWaterSync: onWaterSync,
                onConsumeNotification: onConsumeNotification
            ))
            .sheet(isPresented: $showWeightLog) {
                BodyWeightLogSheet(userId: userId)
            }
    }
}

private struct HomeDashboardAppearModifier: ViewModifier {
    let tabBarState: TabBarState
    let onSync: () -> Void

    func body(content: Content) -> some View {
        content.onAppear {
            tabBarState.resetScrollState()
            onSync()
        }
    }
}

private struct HomeDashboardDataSyncModifier: ViewModifier {
    let habits: [Habit]
    let tasks: [TaskRecord]
    let waterLogs: [WaterLog]
    let foodLogs: [FoodLog]
    let workoutTemplates: [WorkoutTemplate]
    let todaySessions: [WorkoutSession]
    let recentSessions: [WorkoutSession]
    let notificationBridge: WorkoutNotificationBridge
    let onSync: () -> Void
    let onWaterSync: () -> Void
    let onConsumeNotification: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(HomeHabitsTasksSyncModifier(habits: habits, tasks: tasks, onSync: onSync))
            .modifier(HomeWorkoutSyncModifier(
                waterLogs: waterLogs,
                foodLogs: foodLogs,
                workoutTemplates: workoutTemplates,
                todaySessions: todaySessions,
                recentSessions: recentSessions,
                onSync: onSync,
                onWaterSync: onWaterSync
            ))
            .onChange(of: notificationBridge.pendingBuilder?.workoutType) { _, _ in
                onConsumeNotification()
            }
    }
}

private struct HomeHabitsTasksSyncModifier: ViewModifier {
    let habits: [Habit]
    let tasks: [TaskRecord]
    let onSync: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: habits.map(\.id)) { _, _ in onSync() }
            .onChange(of: tasks.map(\.id)) { _, _ in onSync() }
    }
}

private struct HomeWorkoutSyncModifier: ViewModifier {
    let waterLogs: [WaterLog]
    let foodLogs: [FoodLog]
    let workoutTemplates: [WorkoutTemplate]
    let todaySessions: [WorkoutSession]
    let recentSessions: [WorkoutSession]
    let onSync: () -> Void
    let onWaterSync: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: waterLogs.map(\.amountMl)) { _, _ in onWaterSync() }
            .onChange(of: foodLogs.map(\.id)) { _, _ in onSync() }
            .onChange(of: workoutTemplates.map(\.id)) { _, _ in onSync() }
            .onChange(of: todaySessions.map(\.id)) { _, _ in onSync() }
            .onChange(of: recentSessions.map(\.id)) { _, _ in onSync() }
    }
}

private struct HomePresentationModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService
    @Environment(ThemeManager.self) private var themeManager

    let userId: String
    let habits: [Habit]
    @Binding var builderRoute: WorkoutBuilderRoute?
    @Binding var detailSessionRoute: HomeSessionRoute?
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
