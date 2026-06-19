import SwiftUI

// MARK: - Dashed Line

struct DashedLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

struct DashedLine: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(.clear)
            .overlay {
                DashedLineShape()
                    .stroke(
                        theme.colors.streakRing,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            }
    }
}

// MARK: - Section Header

struct SectionHeaderRow: View {
    @Environment(ThemeManager.self) private var theme
    let title: String
    var trailingTitle: String?
    var trailingActionTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack {
            HabfitiseSectionLabel(text: title)

            Spacer()

            if let trailingTitle {
                Text(trailingTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.accentGreen)
            } else if let trailingActionTitle, let trailingAction {
                Button(trailingActionTitle, action: trailingAction)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.accentGreen)
            }
        }
    }
}

// MARK: - Mood Selector

struct MoodSelectorView: View {
    @Environment(ThemeManager.self) private var theme
    @Bindable var viewModel: HomeViewModel
    let userId: String

    @Environment(\.modelContext) private var modelContext

    private let labels = ["Drained", "Low", "Okay", "Good", "Energised"]

    var body: some View {
        VStack(spacing: HabfitiseSpacing.sm) {
            HStack(spacing: HabfitiseSpacing.sm) {
                ForEach(0..<5, id: \.self) { index in
                    Button {
                        viewModel.selectMood(index, userId: userId, context: modelContext)
                    } label: {
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                viewModel.selectedMood == index
                                    ? Color.white
                                    : Color.white.opacity(0.85)
                            )
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(
                                        viewModel.selectedMood == index
                                            ? theme.colors.accentGreen
                                            : theme.colors.streakRing
                                    )
                            )
                            .scaleEffect(viewModel.selectedMood == index ? 1.05 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textMutedOnBackground)
                        .frame(maxWidth: .infinity)
                        .opacity(index == viewModel.selectedMood ? 1 : 0.75)
                }
            }
        }
    }
}

// MARK: - Workout Chips

struct WorkoutChipRow: View {
    @Environment(ThemeManager.self) private var theme
    let chips: [String]

    var body: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .habfitiseChipStyle(
                        color: theme.colors.chipBackground,
                        textColor: theme.colors.textSecondary
                    )
            }
        }
    }
}

// MARK: - Habit Chip

struct HabitCompletionChip: View {
    @Environment(ThemeManager.self) private var theme
    let item: HomeHabitChipItem

    var body: some View {
        HStack(spacing: HabfitiseSpacing.xs) {
            if item.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
            }
            Text(item.name)
                .font(HabfitiseTypography.caption)
        }
        .habfitiseChipStyle(
            color: item.isCompleted ? theme.colors.chipDone : theme.colors.cardBackground,
            textColor: theme.colors.accentGreen
        )
        .overlay {
            if !item.isCompleted {
                Capsule()
                    .strokeBorder(theme.colors.accentGreen, lineWidth: 1)
            }
        }
    }
}

// MARK: - Task Row

struct TaskRowCompact: View {
    @Environment(ThemeManager.self) private var theme
    let task: HomeTaskItem

    var body: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isComplete ? theme.colors.accentGreen : theme.colors.textTertiary)

            Text(task.title)
                .font(HabfitiseTypography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .strikethrough(task.isComplete)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, HabfitiseSpacing.xs)
    }
}

// MARK: - Water Progress

struct WaterProgressBar: View {
    @Environment(ThemeManager.self) private var theme
    let current: Int
    let goal: Int

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.colors.trackBackground)
                    .frame(height: 8)

                Capsule()
                    .fill(theme.colors.waterBlue)
                    .frame(width: geometry.size.width * animatedProgress, height: 8)
            }
        }
        .frame(height: 8)
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

// MARK: - Water Drops

struct WaterCupRow: View {
    let filledCount: Int
    let onTap: () -> Void

    private let dropCount = 6

    var body: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            ForEach(0..<dropCount, id: \.self) { index in
                WaterDropButton(isFilled: index < filledCount, onTap: onTap)
            }
        }
    }
}

private struct WaterDropButton: View {
    let isFilled: Bool
    let onTap: () -> Void

    @Environment(ThemeManager.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var scale: CGFloat = 1

    private var emptyDropColor: Color {
        theme.colors.trackBackground
    }

    var body: some View {
        Button {
            onTap()
            animateTap()
        } label: {
            Image(systemName: "drop.fill")
                .font(.system(size: 28))
                .foregroundStyle(isFilled ? theme.colors.waterBlue : emptyDropColor)
                .frame(width: 28, height: 28)
                .scaleEffect(scale)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isFilled)
    }

    private func animateTap() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
            scale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                scale = 1.2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                scale = 1
            }
        }
    }
}

// MARK: - Weekly Ring

struct WeeklyRingView: View {
    @Environment(ThemeManager.self) private var theme
    let workoutsThisWeek: Int
    let total: Int

    @State private var ringProgress: Double = 0

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(total), 1)
    }

    private var ringColor: Color {
        workoutsThisWeek > 0 ? theme.colors.accentGreen : theme.colors.trackBackground
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.colors.streakRing, lineWidth: 4)

            if workoutsThisWeek > 0 {
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Text("\(workoutsThisWeek)/\(total)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary)
        }
        .frame(width: 80, height: 80)
        .background {
            Circle()
                .fill(theme.colors.cardBackground)
                .frame(width: 56, height: 56)
        }
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

// MARK: - Avatar

struct HomeAvatarView: View {
    @Environment(ThemeManager.self) private var theme
    let displayName: String?

    private var firstLetter: String? {
        guard
            let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
            let first = trimmed.first
        else {
            return nil
        }
        return String(first).uppercased()
    }

    var body: some View {
        Group {
            if let firstLetter {
                Text(firstLetter)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 38, height: 38)
        .background(Circle().fill(theme.colors.accentGreen))
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
        }
    }
}

// MARK: - Header chrome

struct HomeHeaderBackground: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ZStack {
            theme.colors.headerBackground

            RadialGradient(
                colors: [
                    theme.colors.accentGreen.opacity(0.22),
                    theme.colors.headerBackground.opacity(0.05),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 280
            )

            Circle()
                .stroke(theme.colors.textOnBackground.opacity(0.07), lineWidth: 1.5)
                .frame(width: 220, height: 220)
                .offset(x: 90, y: -30)

            Circle()
                .stroke(theme.colors.textOnBackground.opacity(0.05), lineWidth: 1)
                .frame(width: 300, height: 300)
                .offset(x: 110, y: -50)

            Circle()
                .fill(theme.colors.accentGreen.opacity(0.08))
                .frame(width: 120, height: 120)
                .blur(radius: 2)
                .offset(x: -40, y: 60)

            HabfitiseWatermark()
                .offset(x: 48, y: -8)
        }
        .clipShape(HomeHeaderBottomCurve())
    }
}

struct HomeStatPill: View {
    @Environment(ThemeManager.self) private var theme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textMutedOnBackground)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.textOnBackground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, HabfitiseSpacing.md)
        .padding(.vertical, HabfitiseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colors.textOnBackground.opacity(0.1))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.colors.textOnBackground.opacity(0.12), lineWidth: 1)
        }
    }
}

struct HomeGreenHeader: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.homeBodyScrollOffset) private var bodyScrollOffset

    let greeting: String
    let workoutTitle: String
    let memberSince: String
    let profileDisplayName: String?
    let cardOverlap: CGFloat
    @Bindable var viewModel: HomeViewModel
    let userId: String
    let onProfileTap: () -> Void

    private var energyHideProgress: CGFloat {
        min(1, max(0, bodyScrollOffset / 76))
    }

    var body: some View {
        ZStack(alignment: .top) {
            HomeHeaderBackground()

            VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                headerTopRow
                statsRow
                dashedLineSection
                energySection
            }
            .padding(.horizontal, HabfitiseSpacing.lg)
            .padding(.top, HabfitiseSpacing.sm)
            .padding(.bottom, HabfitiseSpacing.xxl + cardOverlap)
            .safeAreaPadding(.top, HabfitiseSpacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var headerTopRow: some View {
        HStack(alignment: .center, spacing: HabfitiseSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.colors.textOnBackground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(workoutTitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.colors.textMutedOnBackground)
                    .lineLimit(1)
            }

            Spacer(minLength: HabfitiseSpacing.sm)

            Button(action: onProfileTap) {
                HomeAvatarView(displayName: profileDisplayName)
            }
            .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.94))
            .accessibilityLabel("Open profile")
        }
    }

    private var statsRow: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            HomeStatPill(title: "Since", value: memberSince)
            HomeStatPill(title: "Today", value: workoutTitle)

            if energyHideProgress > 0.4 {
                compactEnergyBadge
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            Button {} label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textOnBackground.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(themeManager.colors.textOnBackground.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: energyHideProgress > 0.4)
    }

    private var compactEnergyBadge: some View {
        HStack(spacing: 6) {
            Text("⚡")
                .font(.system(size: 12))
            Text("\(viewModel.selectedMood + 1)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.colors.textOnBackground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(themeManager.colors.accentGreen.opacity(0.9))
        )
        .opacity(Double(min(1, (energyHideProgress - 0.4) / 0.45)))
        .scaleEffect(0.88 + min(1, (energyHideProgress - 0.4) / 0.45) * 0.12)
    }

    private var dashedLineSection: some View {
        DashedLine()
            .opacity(Double(1 - energyHideProgress * 0.9))
            .scaleEffect(x: 1, y: 1 - energyHideProgress * 0.5, anchor: .center)
    }

    private var energySection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("How's your energy?")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.colors.textMutedOnBackground)
                .textCase(.uppercase)
                .tracking(0.6)

            MoodSelectorView(viewModel: viewModel, userId: userId)
        }
        .opacity(Double(1 - energyHideProgress))
        .blur(radius: energyHideProgress * 6)
        .scaleEffect(
            x: 1 - energyHideProgress * 0.06,
            y: 1 - energyHideProgress * 0.62,
            anchor: .bottom
        )
        .offset(y: -energyHideProgress * 34)
        .mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(
                    colors: [.black, .black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28 * energyHideProgress)
            }
        }
        .allowsHitTesting(energyHideProgress < 0.35)
        .animation(.interactiveSpring(response: 0.38, dampingFraction: 0.86), value: energyHideProgress)
    }
}

struct HomeHeaderBottomCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 28))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - 28),
            control: CGPoint(x: rect.midX, y: rect.maxY + 18)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Phase scroll

private struct HomeBodyScrollOffsetEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var homeBodyScrollOffset: CGFloat {
        get { self[HomeBodyScrollOffsetEnvironmentKey.self] }
        set { self[HomeBodyScrollOffsetEnvironmentKey.self] = newValue }
    }
}

private struct HomeBodyScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct HomeBodyContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct HomePhaseScrollLayout<Header: View, Content: View>: View {
    let cardOverlap: CGFloat
    let fullHeaderHeight: CGFloat
    let maxHeaderCollapse: CGFloat
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    @State private var headerCollapse: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        GeometryReader { outer in
            let currentHeaderHeight = max(fullHeaderHeight * 0.55, fullHeaderHeight - headerCollapse)
            let bodyHeight = outer.size.height - currentHeaderHeight + cardOverlap

            VStack(spacing: -cardOverlap) {
                header()
                    .frame(height: currentHeaderHeight)
                    .clipped()
                    .animation(.interactiveSpring(response: 0.38, dampingFraction: 0.86), value: headerCollapse)

                bodyScrollView(height: bodyHeight)
            }
        }
        .environment(\.homeBodyScrollOffset, scrollOffset)
        .onPreferenceChange(HomeBodyScrollOffsetKey.self) { scrollOffset = $0 }
        .onPreferenceChange(HomeBodyContentHeightKey.self) { contentHeight = $0 }
        .onChange(of: scrollOffset) { _, offset in
            updateHeaderCollapse(scrollOffset: offset)
        }
        .onChange(of: contentHeight) { _, _ in
            updateHeaderCollapse(scrollOffset: scrollOffset)
        }
        .onChange(of: viewportHeight) { _, _ in
            updateHeaderCollapse(scrollOffset: scrollOffset)
        }
    }

    private func bodyScrollView(height: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                content()
                Color.clear
                    .frame(height: maxHeaderCollapse + cardOverlap)
            }
            .padding(.bottom, 120)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: HomeBodyContentHeightKey.self, value: proxy.size.height)
                }
            }
            .background(alignment: .top) {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: HomeBodyScrollOffsetKey.self,
                            value: -proxy.frame(in: .named(HabfitiseScrollCoordinateSpace.name)).minY
                        )
                }
                .frame(height: 0)
            }
        }
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
        .frame(height: max(0, height))
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { viewportHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, h in viewportHeight = h }
            }
        }
    }

    private func updateHeaderCollapse(scrollOffset: CGFloat) {
        guard viewportHeight > 0, contentHeight > 0 else { return }

        let runway = maxHeaderCollapse + cardOverlap
        let bodyOnlyMax = max(0, contentHeight - viewportHeight - runway)

        if scrollOffset <= bodyOnlyMax {
            if headerCollapse != 0 {
                headerCollapse = 0
            }
        } else {
            let next = min(maxHeaderCollapse, scrollOffset - bodyOnlyMax)
            if abs(next - headerCollapse) > 0.5 {
                headerCollapse = next
            }
        }
    }
}
