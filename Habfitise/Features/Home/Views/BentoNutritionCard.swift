import SwiftUI

struct BentoNutritionCard: View {
    let summary: NutritionDaySummary
    let isPro: Bool
    let onOpenLog: () -> Void
    let onQuickLog: () -> Void

    @Environment(ThemeManager.self) private var theme

    private var calorieProgress: Double {
        guard summary.calorieTarget > 0 else { return 0 }
        return Double(summary.consumedCalories) / Double(summary.calorieTarget)
    }

    private var proteinProgress: Double {
        guard summary.proteinTarget > 0 else { return 0 }
        return Double(summary.consumedProtein) / Double(summary.proteinTarget)
    }

    var body: some View {
        BentoCardContainer(
            title: "Nutrition",
            accent: .nutrition,
            actionTitle: isPro ? "Log" : "Pro",
            action: onQuickLog
        ) {
            HStack(alignment: .center, spacing: HabfitiseSpacing.lg) {
                NutritionDualRingView(
                    calorieProgress: calorieProgress,
                    proteinProgress: proteinProgress,
                    calorieTint: BentoCardAccent.nutrition.focalColor(in: theme.colors),
                    proteinTint: theme.colors.accentGreen
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(summary.consumedCalories)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.colors.textPrimary)
                            .contentTransition(.numericText())

                        Text("/ \(summary.calorieTarget) kcal")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(summary.consumedProtein)g / \(summary.proteinTarget)g protein")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(theme.colors.accentGreen)

                    Text(summary.balanceLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            summary.isOverTarget
                                ? Color(hex: "#FF453A")
                                : theme.colors.textSecondary
                        )

                    if !isPro {
                        Label("AI estimates · Pro", systemImage: "sparkles")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(BentoCardAccent.nutrition.focalColor(in: theme.colors))
                    } else if summary.mealCount > 0 {
                        Text("\(summary.mealCount) meal\(summary.mealCount == 1 ? "" : "s") today")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.colors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenLog)
    }
}
