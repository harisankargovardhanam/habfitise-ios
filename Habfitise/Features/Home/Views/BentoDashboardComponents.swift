import SwiftUI

// MARK: - Sheet clip shape (top corners only)

private struct BentoSheetClipShape: Shape {
    var topRadius: CGFloat = BentoDashboardTheme.sheetRadius

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: topRadius,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: topRadius
                ),
                style: .continuous
            )
        }
    }
}

// MARK: - Scroll offset reader

private struct BentoScrollOffsetReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named(HabfitiseScrollCoordinateSpace.name)).minY
                )
        }
    }
}

// MARK: - Layered dashboard (pinned header + scrolling sheet)

struct BentoCollapsingDashboard<Content: View>: View {
    @Environment(TabBarState.self) private var tabBarState
    @Environment(ThemeManager.self) private var theme

    let greeting: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let profileDisplayName: String?
    let onProfileTap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                BentoScrollOffsetReader()
                    .frame(height: 0)

                content()
                    .padding(.horizontal, HabfitiseSpacing.xl)
                    .padding(.top, HabfitiseSpacing.md)
                    .padding(.bottom, TabBarLayout.tabBarScrollInsetWithFoodLog)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .background(theme.colors.background.ignoresSafeArea(edges: .bottom))
            }
        }
        .contentMargins(.bottom, TabBarLayout.scrollBreathingRoom, for: .scrollContent)
        .background(theme.colors.background.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
            tabBarState.reportScrollOffset(-minY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Equal-width two-column row — `minWidth: 0` prevents HStack children from drifting apart.
struct BentoTwinColumnRow<Left: View, Right: View>: View {
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    var body: some View {
        HStack(alignment: .top, spacing: HabfitiseSpacing.md) {
            left()
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
            right()
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

/// Two-column bento metric grid — paired cells share a fixed row height.
struct BentoMetricGrid<Content: View>: View {
    private let columns = [
        GridItem(.flexible(), spacing: BentoCardStyle.metricGridSpacing),
        GridItem(.flexible(), spacing: BentoCardStyle.metricGridSpacing)
    ]

    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(columns: columns, spacing: BentoCardStyle.metricGridSpacing) {
            content()
        }
    }
}

// MARK: - Header hero

struct BentoCollapsingHeroHeader: View {
    let collapseProgress: CGFloat
    let greeting: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let profileDisplayName: String?
    let onProfileTap: () -> Void

    private var heroOpacity: Double {
        Double(1 - min(collapseProgress * 1.15, 1))
    }

    private var heroScale: CGFloat {
        1 - collapseProgress * 0.1
    }

    var body: some View {
        ZStack(alignment: .top) {
            expandedContent
                .opacity(heroOpacity)
                .scaleEffect(heroScale, anchor: .topLeading)

            compactContent
                .opacity(Double(collapseProgress) * heroOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    private var expandedContent: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                Text(greeting)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(alignment: .firstTextBaseline, spacing: HabfitiseSpacing.xxl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryValue)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(primaryLabel)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(secondaryValue)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(secondaryLabel)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: onProfileTap) {
                BentoProfileAvatar(displayName: profileDisplayName)
            }
            .buttonStyle(.plain)
        }
    }

    private var compactContent: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            Color.clear
                .frame(width: 44, height: 44)

            Text(greeting)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)

            Button(action: onProfileTap) {
                BentoProfileAvatar(displayName: profileDisplayName)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
    }
}

/// Legacy expanded-only header (previews / fallback).
struct BentoHeroHeader: View {
    let greeting: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let profileDisplayName: String?
    let onProfileTap: () -> Void

    var body: some View {
        BentoCollapsingHeroHeader(
            collapseProgress: 0,
            greeting: greeting,
            primaryValue: primaryValue,
            primaryLabel: primaryLabel,
            secondaryValue: secondaryValue,
            secondaryLabel: secondaryLabel,
            profileDisplayName: profileDisplayName,
            onProfileTap: onProfileTap
        )
    }
}

private struct BentoProfileAvatar: View {
    let displayName: String?

    private var initial: String? {
        guard let first = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).first else { return nil }
        return String(first).uppercased()
    }

    var body: some View {
        Group {
            if let initial {
                Text(initial)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundStyle(BentoDashboardTheme.cobalt)
        .frame(width: 44, height: 44)
        .background(Circle().fill(.white))
    }
}

// MARK: - Period picker

struct BentoPeriodPicker: View {
    @Binding var selection: BentoMetricsPeriod
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BentoMetricsPeriod.allCases) { period in
                let isSelected = selection == period

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selection = period
                    }
                } label: {
                    Text(period.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? theme.colors.accentGreen : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(theme.colors.cardBackground)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(theme.colors.fieldBackground)
        )
    }
}

// MARK: - Activity chart

/// Green capsule bar chart body — embed inside `BentoCardContainer`.
struct BentoActivityChartBody: View {
    @Binding var period: BentoMetricsPeriod
    let bars: [BentoActivityBar]
    let maxHeight: CGFloat = 120
    private let idleDotSize: CGFloat = 10

    @State private var barsRevealed = false
    @Environment(ThemeManager.self) private var theme

    private var activeDayCount: Int {
        bars.filter { $0.value > 0 }.count
    }

    private var hasActivity: Bool {
        activeDayCount > 0
    }

    var body: some View {
        let peak = chartPeak(for: bars, period: period)

        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            BentoPeriodPicker(selection: $period)

            if !hasActivity {
                Text("Log a workout to see your activity")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, HabfitiseSpacing.lg)
                    .padding(.horizontal, HabfitiseSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
                            .fill(theme.colors.fieldBackground)
                    )
            } else {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
                    if activeDayCount == 1 {
                        Text("1 workout in this period")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    HStack(alignment: .bottom, spacing: HabfitiseSpacing.sm) {
                        ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                            let animatedHeight = barHeight(for: bar.value, peak: peak)

                            VStack(spacing: 8) {
                                barMark(for: bar, peak: peak)
                                    .frame(height: barsRevealed ? animatedHeight : 0, alignment: .bottom)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.7)
                                            .delay(Double(index) * 0.04),
                                        value: barsRevealed
                                    )

                                Text(bar.label)
                                    .font(.system(size: 11, weight: bar.isCurrent ? .semibold : .medium, design: .rounded))
                                    .foregroundStyle(
                                        bar.isCurrent
                                            ? theme.colors.textPrimary
                                            : theme.colors.textSecondary
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: maxHeight + 24, alignment: .bottom)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HabfitiseSpacing.sm)
                    .padding(.vertical, HabfitiseSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
                            .fill(theme.colors.fieldBackground)
                    )
                }
            }
        }
        .onAppear { revealBars() }
        .onChange(of: bars.map(\.id)) { _, _ in revealBars() }
    }

    @ViewBuilder
    private func barMark(for bar: BentoActivityBar, peak: Double) -> some View {
        if bar.value <= 0 {
            Circle()
                .fill(theme.colors.trackBackground)
                .frame(width: idleDotSize, height: idleDotSize)
        } else if bar.isCurrent {
            Capsule()
                .fill(theme.colors.accentGreen)
                .frame(width: 18)
                .shadow(color: theme.colors.accentGreen.opacity(0.25), radius: 6, y: 3)
        } else {
            Capsule()
                .fill(theme.colors.accentGreen.opacity(0.45))
                .frame(width: 14)
        }
    }

    private func barHeight(for value: Double, peak: Double) -> CGFloat {
        guard value > 0 else { return idleDotSize }
        let ratio = CGFloat(value / peak)
        let capped = min(ratio, 0.72)
        return max(20, maxHeight * capped)
    }

    /// Keeps a single workout from filling the whole chart — bars scale against a sensible floor.
    private func chartPeak(for bars: [BentoActivityBar], period: BentoMetricsPeriod) -> Double {
        let actualMax = bars.map(\.value).max() ?? 0
        let floor: Double = switch period {
        case .day: 45
        case .week: 60
        case .month: 180
        }
        return max(actualMax, floor, 1)
    }

    private func revealBars() {
        barsRevealed = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            barsRevealed = true
        }
    }
}

/// Standalone full-width activity block (legacy / previews).
struct BentoCapsuleChart: View {
    @Binding var period: BentoMetricsPeriod
    let bars: [BentoActivityBar]

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            Text("Activity")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)

            BentoActivityChartBody(period: $period, bars: bars)
        }
    }
}

// MARK: - Pill badge

struct BentoPillBadge: View {
    let text: String
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.colors.accentGreen)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.colors.accentGreen.opacity(0.12))
            )
    }
}

// MARK: - Compact water drops (fits half-width bento cells)

struct BentoWaterDropRow: View {
    let filledCount: Int
    var dropCount: Int = 6
    let onTap: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dropCount, id: \.self) { index in
                Button(action: onTap) {
                    WaterGlassIcon(
                        isFilled: index < filledCount,
                        size: 14,
                        filledColor: BentoCardAccent.water.focalColor(in: theme.colors),
                        emptyColor: theme.colors.trackBackground
                    )
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BentoMetricLabel: View {
    let value: String
    let label: String
    var compact: Bool = false
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        if compact {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Mood (sheet)

struct BentoMoodSelector: View {
    @Bindable var viewModel: HomeViewModel
    let userId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var theme

    private let labels = ["Drained", "Low", "Okay", "Good", "Energised"]
    private let buttonSize: CGFloat = 40
    private let accent = BentoCardAccent.mood

    var body: some View {
        HStack(alignment: .top, spacing: HabfitiseSpacing.sm) {
            ForEach(0..<5, id: \.self) { index in
                let isSelected = viewModel.selectedMood == index

                VStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                            viewModel.selectMood(index, userId: userId, context: modelContext)
                        }
                    } label: {
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(accent.focalColor(in: theme.colors).opacity(0.15))
                                    .frame(width: buttonSize + 12, height: buttonSize + 12)
                            }

                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? Color.white : theme.colors.textPrimary)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(
                                    Circle()
                                        .fill(
                                            isSelected
                                                ? accent.focalColor(in: theme.colors)
                                                : theme.colors.fieldBackground
                                        )
                                )
                        }
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .animation(.spring(response: 0.32, dampingFraction: 0.62), value: isSelected)
                    }
                    .buttonStyle(.plain)

                    Text(labels[index])
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            isSelected
                                ? accent.focalColor(in: theme.colors)
                                : theme.colors.textSecondary
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Water capsule progress

struct BentoWaterProgress: View {
    let current: Int
    let goal: Int

    @State private var animatedProgress: Double = 0
    @Environment(ThemeManager.self) private var theme

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.colors.trackBackground)
                        .frame(height: 14)

                    Capsule()
                        .fill(BentoCardAccent.water.focalColor(in: theme.colors))
                        .frame(width: geometry.size.width * animatedProgress, height: 14)
                }
            }
            .frame(height: 14)

            Text("\(current) / \(goal) ml")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Activity data

enum BentoActivityBuilder {
    static func bars(
        period: BentoMetricsPeriod,
        sessions: [WorkoutSession],
        habitCompletions: Int,
        calendar: Calendar = .current
    ) -> [BentoActivityBar] {
        switch period {
        case .day:
            return dayBars(sessions: sessions, calendar: calendar)
        case .week:
            return weekBars(sessions: sessions, calendar: calendar)
        case .month:
            return monthBars(sessions: sessions, calendar: calendar)
        }
    }

    private static let weekStartFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static func weekBars(sessions: [WorkoutSession], calendar: Calendar) -> [BentoActivityBar] {
        let today = calendar.startOfDay(for: .now)
        let symbols = calendar.shortWeekdaySymbols

        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return BentoActivityBar(id: "\(offset)", label: "-", value: 0, isCurrent: false)
            }
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let minutes = activityMinutes(in: sessions, from: day, until: next)
            let weekday = calendar.component(.weekday, from: day) - 1
            let label = String(symbols[weekday].prefix(2))
            return BentoActivityBar(
                id: "\(offset)",
                label: label,
                value: minutes,
                isCurrent: calendar.isDate(day, inSameDayAs: today)
            )
        }
    }

    private static func dayBars(sessions: [WorkoutSession], calendar: Calendar) -> [BentoActivityBar] {
        let today = calendar.startOfDay(for: .now)
        let labels = ["6a", "9a", "12p", "3p", "6p", "9p", "Now"]
        let bucketEnds = [6, 9, 12, 15, 18, 21, 24]

        return bucketEnds.enumerated().map { index, endHour in
            let startHour = index == 0 ? 0 : bucketEnds[index - 1]
            let minutes = activityMinutes(
                in: sessions,
                on: today,
                fromHour: startHour,
                toHour: endHour,
                calendar: calendar
            )
            return BentoActivityBar(
                id: "\(index)",
                label: labels[index],
                value: minutes,
                isCurrent: index == bucketEnds.count - 1
            )
        }
    }

    private static func monthBars(sessions: [WorkoutSession], calendar: Calendar) -> [BentoActivityBar] {
        let today = calendar.startOfDay(for: .now)
        return (0..<4).map { offset in
            guard
                let weekStart = calendar.date(byAdding: .weekOfYear, value: -(3 - offset), to: today),
                let start = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.start,
                let end = calendar.date(byAdding: .day, value: 7, to: start)
            else {
                return BentoActivityBar(id: "\(offset)", label: "-", value: 0, isCurrent: offset == 3)
            }
            let minutes = activityMinutes(in: sessions, from: start, until: end)
            return BentoActivityBar(
                id: "\(offset)",
                label: weekStartFormatter.string(from: start),
                value: minutes,
                isCurrent: offset == 3
            )
        }
    }

    private static func activityMinutes(
        in sessions: [WorkoutSession],
        from start: Date,
        until end: Date
    ) -> Double {
        sessions.reduce(0) { total, session in
            guard let completed = session.completedAt else { return total }
            guard completed >= start && completed < end else { return total }
            let minutes = max(session.durationSeconds, 60) / 60
            return total + Double(minutes)
        }
    }

    private static func activityMinutes(
        in sessions: [WorkoutSession],
        on day: Date,
        fromHour startHour: Int,
        toHour endHour: Int,
        calendar: Calendar
    ) -> Double {
        sessions.reduce(0) { total, session in
            guard let completed = session.completedAt, calendar.isDate(completed, inSameDayAs: day) else {
                return total
            }
            let hour = calendar.component(.hour, from: completed)
            guard hour >= startHour && hour < endHour else { return total }
            let minutes = max(session.durationSeconds, 60) / 60
            return total + Double(minutes)
        }
    }
}
