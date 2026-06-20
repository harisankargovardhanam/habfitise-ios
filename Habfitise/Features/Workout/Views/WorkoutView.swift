import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService

    @State private var activeWorkoutViewModel: ActiveWorkoutViewModel?

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var allSessions: [WorkoutSession]

    private var sessions: [WorkoutSessionSummary] {
        guard let userId = appState.authenticatedUserId else { return [] }
        return allSessions
            .filter { $0.userId == userId && $0.completedAt != nil }
            .prefix(10)
            .map { session in
                WorkoutSessionSummary(
                    id: session.id,
                    title: session.notes ?? "Workout Session",
                    date: session.completedAt ?? session.startedAt,
                    exerciseCount: 4
                )
            }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: HabfitiseSpacing.lg) {
                HabfitiseTabPageHeader(title: "Workouts")

                VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                    HabfitiseCard {
                        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                            Text("Quick Start")
                                .font(HabfitiseTypography.headline)
                                .foregroundStyle(theme.colors.textPrimary)
                            HabfitisePrimaryButton(title: "New Session") {
                                startNewSession()
                            }
                        }
                    }

                    HabfitiseCard {
                        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                            Text("Recent Sessions")
                                .font(HabfitiseTypography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            if sessions.isEmpty {
                                HabfitiseEmptyState(
                                    icon: "figure.run",
                                    title: "No sessions yet",
                                    subtitle: "Tap New Session to log your first workout"
                                )
                            } else {
                                ForEach(sessions) { session in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(session.title)
                                                .font(HabfitiseTypography.body)
                                                .foregroundStyle(theme.colors.textPrimary)
                                            Text(session.date.formattedShortDate())
                                                .font(HabfitiseTypography.caption)
                                                .foregroundStyle(theme.colors.textSecondary)
                                        }
                                        Spacer()
                                        Text("\(session.exerciseCount) exercises")
                                            .font(HabfitiseTypography.caption)
                                            .foregroundStyle(theme.colors.accentGreen)
                                    }
                                    .padding(.vertical, HabfitiseSpacing.sm)
                                }
                            }
                        }
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
        .fullScreenCover(item: $activeWorkoutViewModel) { workoutVM in
            ActiveWorkoutView(viewModel: workoutVM)
                .environment(appState)
                .environment(syncService)
        }
    }

    private func startNewSession() {
        guard let userId = appState.authenticatedUserId else { return }
        activeWorkoutViewModel = ActiveWorkoutViewModel(
            userId: userId,
            workoutName: "New Session",
            exercises: ActiveWorkoutFactory.defaultExercises(for: "Upper Body Push")
        )
    }
}

private struct WorkoutSessionSummary: Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let exerciseCount: Int
}
