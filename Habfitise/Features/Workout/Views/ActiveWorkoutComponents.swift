import SwiftUI

// MARK: - Exercise Bar Chart

struct ExerciseBarChart: View {
    @Environment(ThemeManager.self) private var theme
    let exercises: [SessionExercise]
    let currentIndex: Int
    var glowCurrentBar = false

    private let maxBarHeight: CGFloat = 88

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                Capsule()
                    .fill(barColor(for: index, exercise: exercise))
                    .frame(
                        width: 18,
                        height: max(8, maxBarHeight * barHeightRatio(for: exercise))
                    )
                    .shadow(
                        color: index == currentIndex && glowCurrentBar
                            ? theme.colors.accentGreen.opacity(0.6)
                            : .clear,
                        radius: index == currentIndex ? 8 : 0
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: exercise.setsCompleted)
                    .animation(.easeInOut(duration: 0.25), value: glowCurrentBar)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .padding(.vertical, HabfitiseSpacing.sm)
        .padding(.horizontal, HabfitiseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
    }

    private func barHeightRatio(for exercise: SessionExercise) -> CGFloat {
        CGFloat(exercise.setProgress)
    }

    private func barColor(for index: Int, exercise: SessionExercise) -> Color {
        if index == currentIndex {
            return theme.colors.accentGreen
        }
        if exercise.setsCompleted >= exercise.totalSets, exercise.totalSets > 0 {
            return theme.colors.accentGreen
        }
        if exercise.setsCompleted > 0 {
            return theme.colors.accentGreen
        }
        return theme.colors.chipBackground
    }
}

// MARK: - Done Button

struct WorkoutDoneButton: View {
    @Environment(ThemeManager.self) private var theme
    let title: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
                    isPressed = false
                }
            }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.colors.accentGreen)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1)
    }
}

// MARK: - Rest Timer Overlay

struct RestTimerOverlay: View {
    @Environment(ThemeManager.self) private var theme
    let countdown: String
    let progress: Double
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: HabfitiseSpacing.lg) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            theme.colors.accentGreen,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 100)
                        .animation(.linear(duration: 1), value: progress)

                    Text(countdown)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                        .monospacedDigit()
                }

                Button("Skip", action: onSkip)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.colors.textPrimary)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Inline Stepper

struct WorkoutInlineStepper: View {
    @Environment(ThemeManager.self) private var theme
    let valueText: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: HabfitiseSpacing.lg) {
            stepperButton(systemName: "minus", action: onDecrement)
            Text(valueText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            stepperButton(systemName: "plus", action: onIncrement)
        }
        .padding(.vertical, HabfitiseSpacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(theme.colors.cardBackground))
        }
        .buttonStyle(HabfitiseScalePressButtonStyle())
    }
}

// MARK: - Stat Column

struct WorkoutStatColumn: View {
    @Environment(ThemeManager.self) private var theme
    let value: String
    let label: String
    var valueColor: Color?
    let onTap: () -> Void

    private var resolvedValueColor: Color {
        valueColor ?? theme.colors.textPrimary
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: HabfitiseSpacing.xs) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(resolvedValueColor)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise List Sheet

struct ExerciseListSheet: View {
    @Environment(ThemeManager.self) private var theme
    let exercises: [SessionExercise]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, HabfitiseSpacing.sm)
                .padding(.bottom, HabfitiseSpacing.lg)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            onSelect(index)
                        } label: {
                            exerciseRow(exercise, index: index)
                        }
                        .buttonStyle(.plain)

                        if index < exercises.count - 1 {
                            Divider().overlay(theme.colors.cardBorder)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, HabfitiseSpacing.lg)
        .padding(.bottom, HabfitiseSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background)
    }

    private func exerciseRow(_ exercise: SessionExercise, index: Int) -> some View {
        HStack(spacing: HabfitiseSpacing.md) {
            if index == currentIndex {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.colors.accentGreen)
                    .frame(width: 3, height: 36)
            } else {
                Color.clear.frame(width: 3, height: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(index == currentIndex ? theme.colors.accentGreen : theme.colors.textPrimary)
                Text("\(exercise.totalSets) sets × \(exercise.targetReps) reps")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            if exercise.setsCompleted >= exercise.totalSets, exercise.totalSets > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.colors.accentGreen)
            }
        }
        .padding(.vertical, HabfitiseSpacing.md)
        .background(
            index == currentIndex
                ? theme.colors.accentGreen.opacity(0.08)
                : Color.clear
        )
    }
}
