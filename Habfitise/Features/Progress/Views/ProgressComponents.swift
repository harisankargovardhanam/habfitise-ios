import SwiftUI

struct ProgressDarkCard<Content: View>: View {
    @Environment(ThemeManager.self) private var theme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.colors.cardBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.colors.cardBorder, lineWidth: 1)
            }
    }
}

struct ProgressStatSummaryCard: View {
    @Environment(ThemeManager.self) private var theme
    let workoutCount: Int
    let habitRate: Double
    let tasksDone: Int

    var body: some View {
        ProgressDarkCard {
            HStack(spacing: HabfitiseSpacing.lg) {
                statBlock(value: "\(workoutCount)", title: "Workouts\nThis Month")
                statBlock(value: "\(Int(habitRate * 100))%", title: "Habit Rate")
                statBlock(value: "\(tasksDone)", title: "Tasks Done")
            }
        }
    }

    private func statBlock(value: String, title: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.colors.accentGreen)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgressWorkoutMinutesCard: View {
    @Environment(ThemeManager.self) private var theme
    let weeklyMinutes: [Double]

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        ProgressDarkCard {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                Text("Workout Minutes")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)

                HStack(alignment: .bottom, spacing: HabfitiseSpacing.md) {
                    ForEach(Array(weeklyMinutes.enumerated()), id: \.offset) { index, minutes in
                        VStack(spacing: HabfitiseSpacing.sm) {
                            if minutes > 0 {
                                HabfitiseCapsuleBar(value: minutes, maxValue: 90, color: theme.colors.accentGreen)
                                    .frame(width: 24, height: 100)
                            } else {
                                Capsule()
                                    .fill(theme.colors.chipBackground)
                                    .frame(width: 24, height: 4)
                            }

                            Text(labels[index])
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct ProgressPersonalRecordsCard: View {
    @Environment(ThemeManager.self) private var theme
    let records: [ProgressPersonalRecord]

    var body: some View {
        ProgressDarkCard {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                Text("Personal Records")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)

                if records.isEmpty {
                    Text("Complete workouts to unlock PRs")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary)
                } else {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            Divider().overlay(theme.colors.cardBorder)
                        }
                        personalRecordRow(record)
                    }
                }
            }
        }
    }

    private func personalRecordRow(_ record: ProgressPersonalRecord) -> some View {
        HStack(alignment: .top) {
            Text(record.exerciseName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.colors.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let valueLabel = record.valueLabel {
                    Text(valueLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                } else {
                    Text(String(format: "%.1f kg × %d", record.weightKg, record.reps))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                }

                changeLabel(for: record)
            }
        }
    }

    @ViewBuilder
    private func changeLabel(for record: ProgressPersonalRecord) -> some View {
        if record.isNewPRThisWeek, let change = record.weeklyChangeKg, change > 0 {
            Text(String(format: "↑ +%.1f kg this week", change))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.colors.accentGreen)
        } else if let change = record.weeklyChangeKg, abs(change) < 0.1 {
            Text("= Same")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary)
        } else if record.isNewPRThisWeek {
            Text("↑ New PR this week")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.colors.accentGreen)
        } else {
            Text("= Same")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary)
        }
    }
}

struct ProgressHabitHeatmapCard: View {
    @Environment(ThemeManager.self) private var theme
    let cells: [HabitHeatmapCell]
    let isPro: Bool
    let onUpgrade: () -> Void

    private let freeWeeks = 4
    private let proWeeks = 10

    var body: some View {
        ProgressDarkCard {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                Text("Habit Consistency")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)

                ZStack(alignment: .trailing) {
                    heatmapGrid

                    if !isPro {
                        proBlurOverlay
                    }
                }
            }
        }
    }

    private var heatmapGrid: some View {
        let weeks = isPro ? proWeeks : freeWeeks

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .trailing, spacing: 3) {
                ForEach(0..<7, id: \.self) { row in
                    Text(["M", "T", "W", "T", "F", "S", "S"][row])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(height: 16)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(0..<weeks, id: \.self) { week in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { row in
                                let index = week * 7 + row
                                if index < cells.count {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(cellColor(cells[index].completionRate))
                                        .frame(width: 16, height: 16)
                                } else {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(theme.colors.chipBackground)
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var proBlurOverlay: some View {
        Button(action: onUpgrade) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 90)

                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pro")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(theme.colors.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
    }

    private func cellColor(_ rate: Double) -> Color {
        if rate >= 1 {
            return theme.colors.accentGreen
        }
        if rate > 0 {
            return theme.colors.accentGreen.opacity(0.45)
        }
        return theme.colors.chipBackground
    }
}

struct ProgressWaterWeekCard: View {
    @Environment(ThemeManager.self) private var theme
    let days: [WaterWeekDay]
    let dailyAverage: Int
    let goalMl: Int

    var body: some View {
        ProgressDarkCard {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                Text("Water This Week")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)

                HStack(alignment: .bottom, spacing: HabfitiseSpacing.sm) {
                    ForEach(days) { day in
                        VStack(spacing: 6) {
                            HabfitiseCapsuleBar(
                                value: Double(day.amountMl),
                                maxValue: Double(max(day.goalMl, 1)),
                                color: theme.colors.waterBlue
                            )
                            .frame(width: 10, height: 50)

                            Text(day.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack {
                    Text("Daily average: \(dailyAverage.formatted()) ml")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary)

                    Spacer()

                    Text("Goal: \(goalMl.formatted()) ml")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
    }
}

struct ProgressExportRow: View {
    @Environment(ThemeManager.self) private var theme
    let exportURL: URL

    var body: some View {
        ShareLink(item: exportURL) {
            HStack(spacing: HabfitiseSpacing.sm) {
                Image(systemName: "square.and.arrow.up")
                Text("Export all data")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.colors.accentGreen)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
