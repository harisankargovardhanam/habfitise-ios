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

    let greeting: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let profileDisplayName: String?
    let onProfileTap: () -> Void
    @ViewBuilder let content: () -> Content

    /// Visual window height — blue header shines through this transparent gap at rest.
    private let headerWindowHeight: CGFloat = 220
    private let bottomScrollPadding: CGFloat = 130

    var body: some View {
        GeometryReader { geo in
            let sheetOverlap = BentoDashboardTheme.sheetRadius
            let transparentGap = headerWindowHeight - sheetOverlap
            let minSheetHeight = geo.size.height - transparentGap + bottomScrollPadding

            ZStack(alignment: .top) {
                // ── Layer 0: Pinned blue header (never scrolls) ──
                pinnedBlueHeader
                    .zIndex(0)

                // ── Layer 1: Single ScrollView — opaque white sheet on top ──
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        BentoScrollOffsetReader()
                            .frame(height: 0)

                        Color.clear
                            .frame(height: transparentGap)

                        content()
                            .padding(.horizontal, HabfitiseSpacing.xl)
                            .padding(.top, HabfitiseSpacing.xxxl)
                            .padding(.bottom, bottomScrollPadding)
                            .frame(maxWidth: .infinity, minHeight: minSheetHeight, alignment: .top)
                            .background {
                                Color.white
                                    .ignoresSafeArea(edges: .bottom)
                            }
                            .clipShape(BentoSheetClipShape())
                            .shadow(color: .black.opacity(0.08), radius: 16, y: -6)
                            .offset(y: -sheetOverlap)
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
                    tabBarState.reportScrollOffset(-minY)
                }
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }

    /// Fixed header: cobalt background, greeting, metrics, avatar — pinned with Spacer below.
    private var pinnedBlueHeader: some View {
        VStack(spacing: 0) {
            BentoHeroHeader(
                greeting: greeting,
                primaryValue: primaryValue,
                primaryLabel: primaryLabel,
                secondaryValue: secondaryValue,
                secondaryLabel: secondaryLabel,
                profileDisplayName: profileDisplayName,
                onProfileTap: onProfileTap
            )
            .padding(.horizontal, HabfitiseSpacing.xxl)
            .padding(.top, HabfitiseSpacing.sm)
            .padding(.bottom, HabfitiseSpacing.xxxl)
            .safeAreaPadding(.top, HabfitiseSpacing.sm)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BentoDashboardTheme.cobalt.ignoresSafeArea(edges: .top))
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
    @Namespace private var pickerNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(BentoMetricsPeriod.allCases) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        selection = period
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == period ? BentoDashboardTheme.cobalt : BentoDashboardTheme.label)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selection == period {
                                Capsule()
                                    .fill(BentoDashboardTheme.softFill)
                                    .matchedGeometryEffect(id: "bentoPeriodPill", in: pickerNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(BentoDashboardTheme.softFill.opacity(0.65))
        )
    }
}

// MARK: - Capsule chart

struct BentoCapsuleChart: View {
    let bars: [BentoActivityBar]
    let maxHeight: CGFloat = 120

    @State private var barsRevealed = false

    var body: some View {
        let peak = max(bars.map(\.value).max() ?? 1, 1)

        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            Text("Activity")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.ink)

            HStack(alignment: .bottom, spacing: HabfitiseSpacing.sm) {
                ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                    let targetHeight = max(12, maxHeight * CGFloat(bar.value / peak))

                    VStack(spacing: 8) {
                        Capsule()
                            .fill(bar.isCurrent ? Color.white : BentoDashboardTheme.cobaltMuted)
                            .frame(
                                width: bar.isCurrent ? 18 : 14,
                                height: barsRevealed ? targetHeight : 0
                            )
                            .overlay {
                                if bar.isCurrent {
                                    Capsule()
                                        .stroke(BentoDashboardTheme.cobalt.opacity(0.15), lineWidth: 1)
                                }
                            }
                            .shadow(color: bar.isCurrent ? BentoDashboardTheme.cobalt.opacity(0.2) : .clear, radius: 8, y: 4)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.04),
                                value: barsRevealed
                            )

                        Text(bar.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(bar.isCurrent ? BentoDashboardTheme.ink : BentoDashboardTheme.label)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, HabfitiseSpacing.sm)
            .padding(.vertical, HabfitiseSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: BentoDashboardTheme.cardRadius, style: .continuous)
                    .fill(BentoDashboardTheme.cobalt)
            )
        }
        .onAppear { revealBars() }
        .onChange(of: bars.map(\.id)) { _, _ in revealBars() }
    }

    private func revealBars() {
        barsRevealed = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            barsRevealed = true
        }
    }
}

// MARK: - Bento cells

struct BentoCell<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
            .padding(HabfitiseSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: BentoDashboardTheme.cardRadius, style: .continuous)
                    .fill(BentoDashboardTheme.sheet)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BentoDashboardTheme.cardRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}

// MARK: - Pill badge

struct BentoPillBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(BentoDashboardTheme.cobalt)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(BentoDashboardTheme.cobalt.opacity(0.1))
            )
    }
}

// MARK: - Compact water drops (fits half-width bento cells)

struct BentoWaterDropRow: View {
    let filledCount: Int
    let onTap: () -> Void

    private let dropCount = 6

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dropCount, id: \.self) { index in
                Button(action: onTap) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            index < filledCount
                                ? BentoDashboardTheme.cobalt
                                : BentoDashboardTheme.softFill
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BentoMetricLabel: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.label)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct BentoSectionTitle: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(BentoDashboardTheme.label)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(BentoDashboardTheme.cobalt)
            }
        }
    }
}

// MARK: - Mood (sheet)

struct BentoMoodSelector: View {
    @Bindable var viewModel: HomeViewModel
    let userId: String

    @Environment(\.modelContext) private var modelContext

    private let labels = ["Drained", "Low", "Okay", "Good", "Energised"]
    private let buttonSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            Text("Energy check-in")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(BentoDashboardTheme.label)

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
                                        .fill(BentoDashboardTheme.cobalt.opacity(0.12))
                                        .frame(width: buttonSize + 12, height: buttonSize + 12)
                                }

                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.white : BentoDashboardTheme.ink)
                                    .frame(width: buttonSize, height: buttonSize)
                                    .background(
                                        Circle()
                                            .fill(isSelected ? BentoDashboardTheme.cobalt : BentoDashboardTheme.softFill)
                                    )
                            }
                            .scaleEffect(isSelected ? 1.15 : 1.0)
                            .animation(.spring(response: 0.32, dampingFraction: 0.62), value: isSelected)
                        }
                        .buttonStyle(.plain)

                        Text(labels[index])
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(isSelected ? BentoDashboardTheme.cobalt : BentoDashboardTheme.label)
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
}

// MARK: - Water capsule progress

struct BentoWaterProgress: View {
    let current: Int
    let goal: Int

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BentoDashboardTheme.softFill)
                        .frame(height: 14)

                    Capsule()
                        .fill(BentoDashboardTheme.cobalt)
                        .frame(width: geometry.size.width * animatedProgress, height: 14)
                }
            }
            .frame(height: 14)

            Text("\(current) / \(goal) ml")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(BentoDashboardTheme.label)
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

    private static func weekBars(sessions: [WorkoutSession], calendar: Calendar) -> [BentoActivityBar] {
        let today = calendar.startOfDay(for: .now)
        let symbols = calendar.shortWeekdaySymbols

        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return BentoActivityBar(id: "\(offset)", label: "-", value: 0, isCurrent: false)
            }
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let count = Double(sessions.filter { session in
                guard let completed = session.completedAt else { return false }
                return completed >= day && completed < next
            }.count)
            let weekday = calendar.component(.weekday, from: day) - 1
            let label = String(symbols[weekday].prefix(1))
            return BentoActivityBar(
                id: "\(offset)",
                label: label,
                value: max(count, 0.15),
                isCurrent: calendar.isDate(day, inSameDayAs: today)
            )
        }
    }

    private static func dayBars(sessions: [WorkoutSession], calendar: Calendar) -> [BentoActivityBar] {
        let today = calendar.startOfDay(for: .now)
        let labels = ["6a", "9a", "12p", "3p", "6p", "9p", "Now"]
        let hours = [6, 9, 12, 15, 18, 21, 23]

        return hours.enumerated().map { index, hour in
            let count = Double(sessions.filter { session in
                guard let completed = session.completedAt, calendar.isDate(completed, inSameDayAs: today) else { return false }
                return calendar.component(.hour, from: completed) <= hour
            }.count)
            return BentoActivityBar(
                id: "\(index)",
                label: labels[index],
                value: max(count, 0.15),
                isCurrent: index == hours.count - 1
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
                return BentoActivityBar(id: "\(offset)", label: "W\(offset + 1)", value: 0.15, isCurrent: offset == 3)
            }
            let count = Double(sessions.filter { session in
                guard let completed = session.completedAt else { return false }
                return completed >= start && completed < end
            }.count)
            return BentoActivityBar(
                id: "\(offset)",
                label: "W\(offset + 1)",
                value: max(count, 0.15),
                isCurrent: offset == 3
            )
        }
    }
}
