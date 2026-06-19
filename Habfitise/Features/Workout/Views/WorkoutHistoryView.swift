import SwiftUI
import SwiftData

// MARK: - Filters

private enum WorkoutHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case weights
    case cardio
    case bodyweight
    case hiit
    case thisWeek
    case thisMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .weights: "Weights"
        case .cardio: "Cardio"
        case .bodyweight: "Bodyweight"
        case .hiit: "HIIT"
        case .thisWeek: "This Week"
        case .thisMonth: "This Month"
        }
    }

    var workoutType: WorkoutType? {
        switch self {
        case .weights: .weights
        case .cardio: .cardio
        case .bodyweight: .bodyweight
        case .hiit: .hiit
        default: nil
        }
    }
}

private struct WorkoutMonthSection: Identifiable {
    let id: String
    let title: String
    let sessions: [WorkoutSession]
}

// MARK: - WorkoutHistoryView (W6)

struct WorkoutHistoryView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState

    let userId: String

    @Query private var sessions: [WorkoutSession]
    @Query private var exerciseSets: [ExerciseSet]

    @State private var selectedFilter: WorkoutHistoryFilter = .all
    @State private var showCalendar = false
    @State private var showFilterBar = true

    private let sheetBackground = Color(hex: "#111111")
    private let cardBackground = Color(hex: "#2A2A2A")
    private let mutedText = Color(hex: "#9CA3AF")

    init(userId: String) {
        self.userId = userId
        _sessions = Query(
            filter: #Predicate<WorkoutSession> { session in
                session.userId == userId && session.completedAt != nil
            },
            sort: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        _exerciseSets = Query(
            filter: #Predicate<ExerciseSet> { set in
                set.userId == userId
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if showFilterBar {
                    filterBar
                }

                calendarSection

                if filteredSessions.isEmpty {
                    emptyState
                } else {
                    ForEach(monthSections) { section in
                        monthSectionView(section)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(sheetBackground.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFilterBar.toggle()
                    }
                } label: {
                    Image(systemName: selectedFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .navigationDestination(for: UUID.self) { sessionId in
            if let session = sessions.first(where: { $0.id == sessionId }) {
                SessionDetailView(session: session)
            }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutHistoryFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedFilter == filter ? sheetBackground : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selectedFilter == filter ? theme.colors.accentGreen : cardBackground)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(hex: "#3A3A3A"), lineWidth: selectedFilter == filter ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Calendar heatmap (Pro)

    @ViewBuilder
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showCalendar.toggle()
                }
            } label: {
                HStack {
                    Text(showCalendar ? "Hide calendar" : "Show calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.accentGreen)
                    Spacer()
                    Image(systemName: showCalendar ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(mutedText)
                }
            }
            .buttonStyle(.plain)

            if showCalendar {
                ZStack {
                    WorkoutVolumeHeatmap(days: heatmapDays)
                        .blur(radius: appState.isPro ? 0 : 5)
                        .allowsHitTesting(appState.isPro)

                    if !appState.isPro {
                        Button {
                            appState.requireUpgrade(for: .advancedAnalytics)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                VStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                    Text("Pro")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
    }

    // MARK: - Month sections

    private func monthSectionView(_ section: WorkoutMonthSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(mutedText)
                    .textCase(.uppercase)
                Spacer()
                Text("\(section.sessions.count) sessions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(mutedText)
            }

            ForEach(section.sessions) { session in
                NavigationLink(value: session.id) {
                    SessionListRow(
                        session: session,
                        hasPRs: prSessionIds.contains(session.id),
                        metrics: metrics(for: session)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(mutedText)
            Text("No sessions match this filter")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Complete a workout to see it here")
                .font(.system(size: 13))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Data

    private var filteredSessions: [WorkoutSession] {
        sessions.filter { session in
            switch selectedFilter {
            case .all:
                return true
            case .thisWeek:
                return Calendar.current.isDate(session.startedAt, equalTo: .now, toGranularity: .weekOfYear)
            case .thisMonth:
                return Calendar.current.isDate(session.startedAt, equalTo: .now, toGranularity: .month)
            default:
                guard let type = selectedFilter.workoutType else { return true }
                return session.type == type
            }
        }
    }

    private var monthSections: [WorkoutMonthSection] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: filteredSessions) { session -> String in
            let date = session.completedAt ?? session.startedAt
            return formatter.string(from: date)
        }

        return grouped.keys.sorted { lhs, rhs in
            guard let left = formatter.date(from: lhs), let right = formatter.date(from: rhs) else {
                return lhs > rhs
            }
            return left > right
        }.map { title in
            WorkoutMonthSection(
                id: title,
                title: title,
                sessions: grouped[title] ?? []
            )
        }
    }

    private var prSessionIds: Set<UUID> {
        Set(exerciseSets.filter(\.isPersonalRecord).map(\.sessionId))
    }

    private var heatmapDays: [WorkoutHeatmapDay] {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .month, value: -2, to: calendar.startOfDay(for: .now)) else {
            return []
        }

        var days: [WorkoutHeatmapDay] = []
        var cursor = start
        let end = calendar.startOfDay(for: .now)

        while cursor <= end {
            let dayStart = cursor
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let volume = sessions.reduce(0.0) { partial, session in
                let date = session.completedAt ?? session.startedAt
                guard date >= dayStart, date < dayEnd else { return partial }
                return partial + session.totalVolumeKg
            }
            days.append(WorkoutHeatmapDay(date: dayStart, volumeKg: volume))
            cursor = dayEnd
        }
        return days
    }

    private func metrics(for session: WorkoutSession) -> SessionListMetrics {
        let sessionSets = exerciseSets.filter { $0.sessionId == session.id }
        let totalDistance = sessionSets.compactMap(\.distanceKm).reduce(0, +)
        return SessionListMetrics(
            primary: session.type == .cardio ? formatDistance(totalDistance) : formatVolume(session.totalVolumeKg),
            duration: formatDuration(session.durationSeconds),
            isCardio: session.type == .cardio
        )
    }

    private func formatVolume(_ kg: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let value = formatter.string(from: NSNumber(value: kg)) ?? "\(Int(kg))"
        return "\(value) kg"
    }

    private func formatDistance(_ km: Double) -> String {
        String(format: "%.1f km", km)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 { return "\(max(minutes, 1))m" }
        return "\(minutes)m \(remainder)s"
    }
}

// MARK: - Session list row

struct SessionListMetrics {
    let primary: String
    let duration: String
    let isCardio: Bool
}

struct SessionListRow: View {
    let session: WorkoutSession
    let hasPRs: Bool
    let metrics: SessionListMetrics

    private let cardBackground = Color(hex: "#2A2A2A")
    private let mutedText = Color(hex: "#9CA3AF")

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WorkoutTypeBadge(type: session.type)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text((session.completedAt ?? session.startedAt).formattedShortDate())
                    .font(.system(size: 12))
                    .foregroundStyle(mutedText)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(metrics.primary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(metrics.duration)
                    .font(.system(size: 12))
                    .foregroundStyle(mutedText)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(alignment: .topTrailing) {
            if hasPRs {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#F59E0B"))
                    .padding(8)
            }
        }
    }
}

// MARK: - Volume heatmap

private struct WorkoutHeatmapDay: Identifiable {
    let id = UUID()
    let date: Date
    let volumeKg: Double
}

private struct WorkoutVolumeHeatmap: View {
    let days: [WorkoutHeatmapDay]

    private let accentGreen = Color(hex: "#22C55E")

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let maxVolume = max(days.map(\.volumeKg).max() ?? 1, 1)

        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(cellColor(volume: day.volumeKg, maxVolume: maxVolume))
                    .frame(height: 16)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .blur(radius: 0)
    }

    private func cellColor(volume: Double, maxVolume: Double) -> Color {
        guard volume > 0 else { return Color(hex: "#1A1A1A") }
        let intensity = min(volume / maxVolume, 1)
        return accentGreen.opacity(0.25 + (0.75 * intensity))
    }
}
