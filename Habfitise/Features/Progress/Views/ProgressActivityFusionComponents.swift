import SwiftUI

struct ProgressWellnessScoreCard: View {
    @Environment(ThemeManager.self) private var theme
    let score: WellnessScore

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wellness score")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("Workouts, steps, habits, and water today")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                }
                Spacer()
                Text("\(score.score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.accentGreen)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.colors.trackBackground)
                    Capsule()
                        .fill(theme.colors.accentGreen)
                        .frame(width: geo.size.width * CGFloat(score.score) / 100)
                }
            }
            .frame(height: 8)

            HStack(spacing: 0) {
                pillar(label: "Workout", value: score.workoutPoints, max: 30, tint: Color(hex: "#BF5AF2"))
                pillar(label: "Steps", value: score.stepsPoints, max: 30, tint: Color(hex: "#FF375F"))
                pillar(label: "Habits", value: score.habitsPoints, max: 25, tint: Color(hex: "#A6FF00"))
                pillar(label: "Water", value: score.waterPoints, max: 15, tint: Color(hex: "#00D4FF"))
            }
        }
        .padding(HabfitiseSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
    }

    private func pillar(label: String, value: Int, max: Int, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
            Capsule()
                .fill(tint.opacity(0.25))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: max > 0 ? CGFloat(value) / CGFloat(max) : 0, anchor: .leading)
                }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgressTrainingLoadCard: View {
    @Environment(ThemeManager.self) private var theme
    let days: [TrainingTrendDay]

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training vs movement")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                Text("VAYA workout minutes and daily steps")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: "#FF375F").opacity(day.isToday ? 0.35 : 0.18))
                                .frame(height: barHeight(day.steps, cap: maxSteps))

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: "#BF5AF2").opacity(day.isToday ? 1 : 0.65))
                                .frame(width: 10, height: barHeight(Int(day.workoutMinutes), cap: maxWorkoutMinutes))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 88, alignment: .bottom)

                        Text(day.label)
                            .font(.system(size: 10, weight: day.isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(day.isToday ? theme.colors.textPrimary : theme.colors.textSecondary)
                    }
                }
            }

            HStack(spacing: 16) {
                legend(color: Color(hex: "#BF5AF2"), label: "Workout min")
                legend(color: Color(hex: "#FF375F"), label: "Steps")
            }
        }
        .padding(HabfitiseSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
    }

    private var maxSteps: Int {
        max(days.map(\.steps).max() ?? 1, 1)
    }

    private var maxWorkoutMinutes: Int {
        max(Int(days.map(\.workoutMinutes).max() ?? 1), 1)
    }

    private func barHeight(_ value: Int, cap: Int) -> CGFloat {
        guard cap > 0 else { return 4 }
        return max(4, 72 * CGFloat(value) / CGFloat(cap))
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
        }
    }
}
