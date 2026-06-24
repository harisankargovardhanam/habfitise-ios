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
    private let buttonSize: CGFloat = 38

    var body: some View {
        HStack(alignment: .top, spacing: HabfitiseSpacing.sm) {
            ForEach(0..<5, id: \.self) { index in
                VStack(spacing: HabfitiseSpacing.sm) {
                    Button {
                        viewModel.selectMood(index, userId: userId, context: modelContext)
                    } label: {
                        ZStack {
                            HabfitisePulseRing(isActive: viewModel.selectedMood == index)
                                .frame(width: buttonSize + 10, height: buttonSize + 10)

                            Text("\(index + 1)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                viewModel.selectedMood == index
                                    ? Color.white
                                    : theme.colors.textPrimary
                            )
                            .frame(width: buttonSize, height: buttonSize)
                            .background(
                                Circle()
                                    .fill(
                                        viewModel.selectedMood == index
                                            ? theme.colors.accentGreen
                                            : theme.colors.trackBackground
                                    )
                            )
                            .scaleEffect(viewModel.selectedMood == index ? 1.05 : 1)
                        }
                    }
                    .buttonStyle(.plain)

                    Text(labels[index])
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .opacity(index == viewModel.selectedMood ? 1 : 0.75)
                }
                .frame(maxWidth: .infinity)
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

// MARK: - Home status rows (read-only glance — edit on Habits / Tasks tabs)

struct BentoHomeStatusRow: View {
    enum Style {
        case habit
        case task

        var pendingLabel: String {
            switch self {
            case .habit: "Not yet"
            case .task: "Open"
            }
        }
    }

    @Environment(ThemeManager.self) private var theme

    let title: String
    let isDone: Bool
    let style: Style

    var body: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            Text(title)
                .font(.system(size: 14, weight: isDone ? .regular : .semibold, design: .rounded))
                .foregroundStyle(isDone ? theme.colors.textSecondary : theme.colors.textPrimary)
                .strikethrough(isDone, color: theme.colors.textTertiary)
                .lineLimit(1)
                .animation(.easeOut(duration: 0.2), value: isDone)

            Spacer(minLength: 0)

            statusBadge
        }
        .padding(.horizontal, HabfitiseSpacing.md)
        .padding(.vertical, HabfitiseSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDone
                    ? theme.colors.fieldBackground.opacity(0.55)
                    : theme.colors.fieldBackground)
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(isDone ? "Done" : style.pendingLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(isDone ? theme.colors.accentGreen : theme.colors.textSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                isDone
                    ? theme.colors.accentGreen.opacity(0.14)
                    : theme.colors.chipBackground
            )
        )
        .accessibilityLabel(isDone ? "Completed" : style.pendingLabel)
    }
}

// MARK: - Habit Chip

struct HabitCompletionChip: View {
    @Environment(ThemeManager.self) private var theme
    let item: HomeHabitChipItem

    var body: some View {
        HStack(spacing: HabfitiseSpacing.xs) {
            Text(item.name)
                .font(HabfitiseTypography.caption)
                .strikethrough(item.isCompleted, color: theme.colors.textTertiary)
            if item.isCompleted {
                Text("Done")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.accentGreen)
            }
        }
        .habfitiseChipStyle(
            color: item.isCompleted ? theme.colors.chipDone : theme.colors.cardBackground,
            textColor: item.isCompleted ? theme.colors.textSecondary : theme.colors.textPrimary
        )
    }
}

// MARK: - Task Row

struct TaskRowCompact: View {
    @Environment(ThemeManager.self) private var theme
    let task: HomeTaskItem

    var body: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            Text(task.title)
                .font(HabfitiseTypography.body)
                .foregroundStyle(task.isComplete ? theme.colors.textSecondary : theme.colors.textPrimary)
                .strikethrough(task.isComplete, color: theme.colors.textTertiary)
                .lineLimit(1)

            Spacer()

            Text(task.isComplete ? "Done" : "Open")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(task.isComplete ? theme.colors.accentGreen : theme.colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(
                        task.isComplete
                            ? theme.colors.accentGreen.opacity(0.14)
                            : theme.colors.chipBackground
                    )
                )
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
    @State private var scale: CGFloat = 1

    var body: some View {
        Button {
            onTap()
            animateTap()
        } label: {
            WaterGlassIcon(isFilled: isFilled, size: 28)
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

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            theme.colors.accentGreen,
                            Color(hex: "#FF375F"),
                            Color(hex: "#FF9500"),
                            theme.colors.accentGreen
                        ],
                        center: .center
                    ),
                    lineWidth: 2.5
                )

            Circle()
                .fill(theme.colors.fieldBackground)
                .padding(3)

            Image(systemName: "person.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(width: 38, height: 38)
        .accessibilityLabel(profileAccessibilityLabel)
    }

    private var profileAccessibilityLabel: String {
        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "Profile, \(name)"
        }
        return "Profile"
    }
}

// MARK: - Home layout

struct HomeStatPill: View {
    @Environment(ThemeManager.self) private var theme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, HabfitiseSpacing.md)
        .padding(.vertical, HabfitiseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colors.fieldBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.colors.cardBorder, lineWidth: 1)
        }
    }
}

/// Scrolls with content — no overlays, no fixed heights.
struct HomeSimpleHeader: View {
    @Environment(ThemeManager.self) private var theme

    let greeting: String
    let subtitle: String
    let memberSince: String
    let profileDisplayName: String?
    @Bindable var viewModel: HomeViewModel
    let userId: String
    let onProfileTap: () -> Void

    private var todayLabel: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            HStack(alignment: .top, spacing: HabfitiseSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: onProfileTap) {
                    HomeAvatarView(displayName: profileDisplayName)
                }
                .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.94))
                .accessibilityLabel("Open profile")
            }

            HStack(spacing: HabfitiseSpacing.sm) {
                HomeStatPill(title: "Since", value: memberSince)
                HomeStatPill(title: "Today", value: todayLabel)
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(theme.colors.cardBorder)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
                Text("How's your energy?")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                MoodSelectorView(viewModel: viewModel, userId: userId)
            }
        }
        .padding(.horizontal, HabfitiseSpacing.lg)
        .safeAreaPadding(.top, HabfitiseSpacing.sm)
        .padding(.bottom, HabfitiseSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
