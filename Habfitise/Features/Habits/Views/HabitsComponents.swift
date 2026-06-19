import SwiftUI

// MARK: - Habit Card

struct HabitCard: View {
    @Environment(ThemeManager.self) private var theme
    let habit: Habit
    let days: [HabitDayItem]
    let streak: Int
    let isCompletedToday: Bool
    let onComplete: () -> Void

    @State private var todaySquareScale: CGFloat = 1
    @State private var displayStreak: Int
    @State private var showParticles = false
    @State private var buttonDone = false
    @State private var optimisticTodayComplete = false

    init(
        habit: Habit,
        days: [HabitDayItem],
        streak: Int,
        isCompletedToday: Bool,
        onComplete: @escaping () -> Void
    ) {
        self.habit = habit
        self.days = days
        self.streak = streak
        self.isCompletedToday = isCompletedToday
        self.onComplete = onComplete
        _displayStreak = State(initialValue: streak)
        _buttonDone = State(initialValue: isCompletedToday)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            SevenDayGrid(
                days: days,
                todayScale: todaySquareScale,
                optimisticTodayComplete: optimisticTodayComplete
            )
            .padding(.top, 10)
            doneButton
                .padding(.top, 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.colors.cardBorder, lineWidth: 1)
        }
        .overlay {
            if showParticles {
                MilestoneParticleBurst()
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: isCompletedToday) { _, completed in
            buttonDone = completed
        }
        .onChange(of: streak) { _, value in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                displayStreak = value
            }
            if HabitStreakMilestone.isMilestone(value) {
                triggerParticles()
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            Circle()
                .fill(Color(hex: "#\(habit.colorHex)"))
                .frame(width: 10, height: 10)

            Text(habit.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Circle()
                .fill(theme.colors.percentageOrange)
                .frame(width: 6, height: 6)

            Text("\(displayStreak)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.percentageOrange)
                .contentTransition(.numericText())
        }
    }

    private var doneButton: some View {
        Button {
            guard !buttonDone else { return }
            performCompletion()
        } label: {
            HStack(spacing: HabfitiseSpacing.sm) {
                if !buttonDone {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(buttonDone ? "✓ Done today" : "Done today")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(
                buttonDone
                    ? theme.colors.accentGreen
                    : Color.white
            )
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        buttonDone
                            ? theme.colors.chipDone
                            : theme.colors.accentGreen
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(buttonDone)
        .animation(.easeInOut(duration: 0.2), value: buttonDone)
    }

    private func performCompletion() {
        todaySquareScale = 0.8
        optimisticTodayComplete = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            todaySquareScale = 1.15
            buttonDone = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                todaySquareScale = 1
            }
        }

        onComplete()
    }

    private func triggerParticles() {
        HabfitiseHaptics.milestone()
        showParticles = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeOut(duration: 0.25)) {
                showParticles = false
            }
        }
    }
}

// MARK: - Seven Day Grid

struct SevenDayGrid: View {
    @Environment(ThemeManager.self) private var theme
    let days: [HabitDayItem]
    var todayScale: CGFloat = 1
    var optimisticTodayComplete = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    DaySquare(
                        day: day,
                        scale: day.isToday ? todayScale : 1,
                        forceCompleted: day.isToday && optimisticTodayComplete
                    )
                    Text(day.weekdayLabel)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Day Square

struct DaySquare: View {
    @Environment(ThemeManager.self) private var theme
    let day: HabitDayItem
    var scale: CGFloat = 1
    var forceCompleted = false

    private var isCompleted: Bool {
        day.isCompleted || forceCompleted
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(fillColor)
            .frame(width: 30, height: 30)
            .overlay {
                if day.isToday, !isCompleted, !day.isFuture {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(theme.colors.accentGreen, lineWidth: 2)
                }
            }
            .scaleEffect(scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isCompleted)
    }

    private var fillColor: Color {
        if isCompleted {
            return theme.colors.accentGreen
        }
        if day.isFuture {
            return theme.colors.trackBackground
        }
        if day.isToday {
            return .clear
        }
        return theme.colors.trackBackground
    }
}

// MARK: - Milestone Particles

struct MilestoneParticleBurst: View {
    @Environment(ThemeManager.self) private var theme
    @State private var progress: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let particleCount = 18

            for index in 0..<particleCount {
                let angle = (Double(index) / Double(particleCount)) * .pi * 2
                let distance = 40 * progress
                let point = CGPoint(
                    x: center.x + cos(angle) * distance,
                    y: center.y + sin(angle) * distance
                )
                let radius = max(2, 4 * (1 - progress))
                let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(theme.colors.percentageOrange.opacity(Double(1 - progress)))
                )
            }
        }
        .opacity(Double(1 - progress * 0.8))
        .onAppear {
            withAnimation(.easeOut(duration: 1)) {
                progress = 1
            }
        }
    }
}

// MARK: - Add Habit Row

struct AddHabitRow: View {
    @Environment(ThemeManager.self) private var theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HabfitiseSpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Add a habit")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundStyle(theme.colors.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        theme.colors.trackBackground,
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Water Intake Card

struct WaterIntakeCard: View {
    @Environment(ThemeManager.self) private var theme
    let waterToday: Int
    let waterGoal: Int
    let filledCups: Int
    let cupCount: Int
    let animatingCupIndex: Int?
    let celebrationActive: Bool
    let nextReminderMinutes: Int
    let onCupTap: (Int) -> Void
    var onEdit: (() -> Void)?
    var onAddWater: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            headerRow
            HabitsWaterProgressBar(current: waterToday, goal: waterGoal)

            HStack(spacing: HabfitiseSpacing.md) {
                ForEach(0..<cupCount, id: \.self) { index in
                    HabitsWaterDropButton(
                        isFilled: index < filledCups,
                        isAnimating: animatingCupIndex == index,
                        onTap: { onCupTap(index) }
                    )
                }
            }

            footerRow

            if let onAddWater {
                Button(action: onAddWater) {
                    Text("+ Add water")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.waterBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.colors.waterButtonBackground)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    celebrationActive
                        ? theme.colors.accentGreen
                        : theme.colors.cardBorder,
                    lineWidth: celebrationActive ? 2 : 1
                )
                .shadow(color: celebrationActive ? theme.colors.accentGreen.opacity(0.35) : .clear, radius: 8)
                .animation(.easeInOut(duration: 0.45).repeatCount(celebrationActive ? 2 : 0, autoreverses: true), value: celebrationActive)
        }
    }

    private var headerRow: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            Image(systemName: "drop.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.colors.waterBlue)

            Text("Water intake")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)

            Spacer()

            Text("\(waterToday) / \(waterGoal) ml")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.waterBlue)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var footerRow: some View {
        HStack(spacing: HabfitiseSpacing.xs) {
            Image(systemName: "bell.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary)

            Text("Next reminder in \(nextReminderMinutes) min")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)

            Spacer()

            if let onEdit {
                Button("Edit", action: onEdit)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.waterBlue)
            }
        }
    }
}

// MARK: - Water Progress Bar

struct HabitsWaterProgressBar: View {
    @Environment(ThemeManager.self) private var theme
    let current: Int
    let goal: Int

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
                    .frame(width: geometry.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: progress)
    }
}

struct HabitsWaterDropButton: View {
    @Environment(ThemeManager.self) private var theme
    let isFilled: Bool
    let isAnimating: Bool
    let onTap: () -> Void

    @State private var bounceScale: CGFloat = 1

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: "drop.fill")
                .font(.system(size: 28))
                .foregroundStyle(isFilled ? theme.colors.waterBlue : theme.colors.trackBackground)
                .frame(width: 28, height: 28)
                .scaleEffect(bounceScale)
        }
        .buttonStyle(.plain)
        .onChange(of: isAnimating) { _, animating in
            if animating { runTapAnimation() }
        }
    }

    private func handleTap() {
        onTap()
    }

    private func runTapAnimation() {
        bounceScale = 0.8
        withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) {
            bounceScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                bounceScale = 1
            }
        }
    }
}

// MARK: - Plus Button

struct HabitsAddButton: View {
    @Environment(ThemeManager.self) private var theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 34, height: 34)

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(.plain)
    }
}
