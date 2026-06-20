import SwiftUI
import SwiftData

// MARK: - Workout Hub (W1)

struct WorkoutsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService
    @Environment(ThemeManager.self) private var theme

    @State private var builderRoute: WorkoutBuilderRoute?
    @State private var showHistory = false

    var body: some View {
        Group {
            if let userId = appState.authenticatedUserId {
                WorkoutsContentView(
                    userId: userId,
                    showHistory: $showHistory,
                    onOpenBuilder: openBuilder
                )
            } else {
                ProgressView()
                    .tint(theme.colors.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.background.ignoresSafeArea())
            }
        }
        .fullScreenCover(item: $builderRoute) { route in
            WorkoutBuilderView(type: route.type, template: route.template)
                .environment(appState)
                .environment(syncService)
                .environment(theme)
        }
    }

    private func openBuilder(type: WorkoutType, template: WorkoutTemplate?) {
        builderRoute = WorkoutBuilderRoute(type: type, template: template)
    }
}

private struct WorkoutsContentView: View {
    let userId: String
    @Binding var showHistory: Bool
    let onOpenBuilder: (WorkoutType, WorkoutTemplate?) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var theme

    @State private var selectedSession: WorkoutSession?
    @State private var showCardioPicker = false
    @State private var streakStats = WorkoutStreakStats(currentStreak: 0, bestStreak: 0, monthCompleted: 0, monthPlanned: 16, consistency30Day: 0)
    @State private var aiSuggestion: WorkoutSuggestion?
    @State private var showAISuggestion = true

    @Query private var templates: [WorkoutTemplate]
    @Query private var recentSessions: [WorkoutSession]
    @Query private var missedWorkouts: [MissedWorkout]
    @Query private var exerciseSets: [ExerciseSet]

    init(
        userId: String,
        showHistory: Binding<Bool>,
        onOpenBuilder: @escaping (WorkoutType, WorkoutTemplate?) -> Void
    ) {
        self.userId = userId
        _showHistory = showHistory
        self.onOpenBuilder = onOpenBuilder

        _templates = Query(
            filter: #Predicate<WorkoutTemplate> { $0.userId == userId },
            sort: [SortDescriptor(\.lastPerformedAt, order: .reverse)]
        )
        _recentSessions = Query(
            filter: #Predicate<WorkoutSession> { session in
                session.userId == userId && session.completedAt != nil
            },
            sort: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        _missedWorkouts = Query(
            filter: #Predicate<MissedWorkout> { missed in
                missed.userId == userId
            },
            sort: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        _exerciseSets = Query(
            filter: #Predicate<ExerciseSet> { $0.userId == userId }
        )
    }

    private var todayScheduled: WorkoutTemplate? {
        templates.first { template in
            guard let scheduled = template.nextScheduledAt else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }
    }

    private var isScheduledMissed: Bool {
        guard let scheduled = todayScheduled?.nextScheduledAt else { return false }
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return scheduled < startOfToday
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: HabfitiseSpacing.lg) {
                HabfitiseTabPageHeader(title: "Workouts") {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.colors.textPrimary)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                    if !pendingMissedItems.isEmpty {
                        missedWorkoutsSection
                    }
                    quickStartSection
                    WorkoutStreakCard(stats: streakStats)
                    if let scheduled = todayScheduled {
                        scheduledSection(template: scheduled, isMissed: isScheduledMissed)
                    }
                    templatesSection
                    if showAISuggestion, let aiSuggestion, recentSessions.count >= 4 {
                        WorkoutAISuggestionCard(
                            suggestion: aiSuggestion,
                            isPro: appState.isPro,
                            onSave: { saveSuggestionTemplate(aiSuggestion) },
                            onDismiss: {
                                showAISuggestion = false
                                UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.dismissedWorkoutSuggestion)
                            },
                            onUpgrade: { appState.requireUpgrade(for: .aiDailyPlan) }
                        )
                    }
                    recentSessionsSection
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
        .navigationDestination(isPresented: $showHistory) {
            WorkoutHistoryView(userId: userId)
        }
        .habfitiseTabScreen(immersiveHeader: true)
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                SessionDetailView(session: session, showsDoneButton: true)
            }
        }
        .confirmationDialog("Choose cardio type", isPresented: $showCardioPicker, titleVisibility: .visible) {
            Button("Outdoor Run") { launchQuickStart(type: .cardio) }
            Button("Treadmill") { launchQuickStart(type: .cardio) }
            Button("Cycling") { launchQuickStart(type: .cardio) }
            Button("Walking") { launchQuickStart(type: .cardio) }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: refreshEnhancementData)
        .onChange(of: recentSessions.count) { _, _ in refreshEnhancementData() }
    }

    private func refreshEnhancementData() {
        streakStats = WorkoutAnalytics.streakStats(userId: userId, context: modelContext)
        showAISuggestion = !UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.dismissedWorkoutSuggestion)
        aiSuggestion = WorkoutAnalytics.localWorkoutSuggestion(sessions: recentSessions, sets: exerciseSets)
    }

    private func saveSuggestionTemplate(_ suggestion: WorkoutSuggestion) {
        let template = WorkoutTemplate(
            userId: userId,
            name: suggestion.name,
            type: suggestion.type,
            estimatedMinutes: 45,
            synced: false
        )
        modelContext.insert(template)
        try? modelContext.save()
        showAISuggestion = false
    }

    // MARK: - Sections

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)

            Text("Log an ad-hoc session without a template")
                .font(.system(size: 13))
                .foregroundStyle(theme.colors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                quickStartButton(type: .weights, icon: "dumbbell.fill", label: "Weights")
                quickStartButton(type: .cardio, icon: "figure.run", label: "Cardio", showsSubtypes: true)
                quickStartButton(type: .bodyweight, icon: "figure.jumprope", label: "Bodyweight")
                quickStartButton(type: .hiit, icon: "bolt.heart.fill", label: "HIIT")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.colors.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.colors.cardBorder, lineWidth: 1)
                )
        )
    }

    private var pendingMissedItems: [(missed: MissedWorkout, template: WorkoutTemplate)] {
        missedWorkouts
            .filter { $0.action == .pending }
            .compactMap { missed in
            guard let template = templates.first(where: { $0.id == missed.templateId }) else { return nil }
            return (missed, template)
        }
    }

    private var missedWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(pendingMissedItems, id: \.missed.id) { item in
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
        }
    }

    private func scheduledSection(template: WorkoutTemplate, isMissed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SCHEDULED TODAY")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary)

            ScheduledWorkoutCard(
                template: template,
                isMissed: isMissed,
                onStart: { onOpenBuilder(template.type, template) }
            )
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MY TEMPLATES")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary)
                Spacer()
                Button {
                    launchQuickStart(type: .weights)
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.accentGreen)
                }
            }

            if templates.isEmpty {
                templatesEmptyState
            } else {
                ForEach(templates) { template in
                    TemplateCard(
                        template: template,
                        onTap: { onOpenBuilder(template.type, template) },
                        onDelete: { deleteTemplate(template) },
                        onStartNow: { onOpenBuilder(template.type, template) }
                    )
                }
            }
        }
    }

    private var templatesEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundStyle(theme.colors.accentGreen.opacity(0.4))
            Text("No templates yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
            Text("Build a workout to save and repeat")
                .font(.system(size: 13))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colors.fieldBackground)
        )
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT SESSIONS")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary)

            if recentSessions.prefix(5).isEmpty {
                Text("No sessions logged yet")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.colors.fieldBackground)
                    )
            } else {
                ForEach(Array(recentSessions.prefix(5))) { session in
                    RecentSessionRow(session: session)
                        .onTapGesture { selectedSession = session }
                }
            }
        }
    }

    // MARK: - Actions

    private func quickStartButton(
        type: WorkoutType,
        icon: String,
        label: String,
        showsSubtypes: Bool = false
    ) -> some View {
        Button {
            if showsSubtypes {
                showCardioPicker = true
            } else {
                launchQuickStart(type: type)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(theme.colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.colors.chipBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.colors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func launchQuickStart(type: WorkoutType) {
        onOpenBuilder(type, nil)
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
    }
}

struct WorkoutBuilderRoute: Identifiable {
    let id = UUID()
    let type: WorkoutType
    let template: WorkoutTemplate?
}

// MARK: - WorkoutTypeBadge

struct WorkoutTypeBadge: View {
    let type: WorkoutType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(shortLabel)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(background))
    }

    private var shortLabel: String {
        switch type {
        case .weights: "Weights"
        case .cardio: "Cardio"
        case .bodyweight: "Bodyweight"
        case .hiit: "HIIT"
        case .flexibility: "Flexibility"
        }
    }

    private var background: Color {
        switch type {
        case .weights: Color(hex: "#1A3A1A")
        case .cardio: Color(hex: "#1A2A4A")
        case .bodyweight: Color(hex: "#2A1A2A")
        case .hiit: Color(hex: "#3A1A1A")
        case .flexibility: Color(hex: "#1A2A2A")
        }
    }

    private var foreground: Color {
        switch type {
        case .weights: Color(hex: "#22C55E")
        case .cardio: Color(hex: "#3B82F6")
        case .bodyweight: Color(hex: "#A855F7")
        case .hiit: Color(hex: "#FF6B35")
        case .flexibility: Color(hex: "#06B6D4")
        }
    }
}

// MARK: - ScheduledWorkoutCard

private struct ScheduledWorkoutCard: View {
    @Environment(ThemeManager.self) private var theme

    let template: WorkoutTemplate
    let isMissed: Bool
    let onStart: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                HStack(spacing: 8) {
                    WorkoutTypeBadge(type: template.type)
                    Text("\(template.exercises.count) exercises · ~\(template.estimatedMinutes) min")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            Spacer()
            if isMissed {
                Text("Missed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.danger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(theme.colors.danger.opacity(0.15)))
            } else {
                Button(action: onStart) {
                    Text("Start")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.textOnBackground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(theme.colors.accentGreen))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colors.fieldBackground)
                .overlay(alignment: .leading) {
                    if isMissed {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.colors.danger)
                            .frame(width: 3)
                    }
                }
        )
    }
}

// MARK: - TemplateCard

private struct TemplateCard: View {
    @Environment(ThemeManager.self) private var theme

    let template: WorkoutTemplate
    let onTap: () -> Void
    let onDelete: () -> Void
    let onStartNow: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    WorkoutTypeBadge(type: template.type)
                    Spacer()
                    Menu {
                        Button("Start now", action: onStartNow)
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(theme.colors.textSecondary)
                            .padding(4)
                    }
                }

                Text(template.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)

                Text("\(template.exercises.count) exercises · ~\(template.estimatedMinutes) min")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.colors.textSecondary)

                if let next = template.nextScheduledAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(next.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(theme.colors.accentGreen)
                }

                if let last = template.lastPerformedAt {
                    Text("Last: \(last.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.colors.textTertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.colors.fieldBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RecentSessionRow

private struct RecentSessionRow: View {
    @Environment(ThemeManager.self) private var theme
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    WorkoutTypeBadge(type: session.type)
                    Text(session.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(durationLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.colors.textPrimary)
                Text((session.completedAt ?? session.startedAt).formattedShortDate())
                    .font(.system(size: 12))
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colors.fieldBackground)
        )
    }

    private var durationLabel: String {
        let minutes = max(session.durationSeconds / 60, 1)
        return "\(minutes) min"
    }
}

#if DEBUG
struct WorkoutsView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutsView()
            .environment(AppState())
            .environment(SyncService())
            .environment(ThemeManager())
            .modelContainer(try! SwiftDataStack.makeContainer(inMemory: true))
    }
}
#endif
