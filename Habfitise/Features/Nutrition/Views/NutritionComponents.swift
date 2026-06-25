import SwiftUI

// MARK: - Macro range hero

struct NutritionMacroRangeView: View {
    let title: String
    let unit: String
    let range: NutritionMacroRange
    let tint: Color
    let progress: Double

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.colors.textSecondary)

                Spacer(minLength: 0)

                Text("\(range.low)–\(range.high) \(unit)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(range.mid)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                    .contentTransition(.numericText())

                Text(unit)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.colors.trackBackground)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.65), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Source banner

struct NutritionSourceBanner: View {
    let source: NutritionEstimateSource
    let label: String

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        if source.showsAICaution {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#FF9500"))
                Text(source == .mixed
                     ? "Some items matched our food database; AI estimated the rest."
                     : "Not in our food database — using AI to estimate. Treat as a rough guess.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(HabfitiseSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#FF9500").opacity(0.12))
            )
        } else {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.accentGreen)
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
    }
}

// MARK: - Estimate result card

struct NutritionEstimateResultCard: View {
    let estimate: NutritionEstimateDraft
    let calorieProgress: Double
    let proteinProgress: Double

    @Environment(ThemeManager.self) private var theme

    private var confidenceLabel: String {
        switch estimate.confidence.lowercased() {
        case "high": "High confidence"
        case "medium": "Medium confidence"
        default: "Low confidence — wider range"
        }
    }

    private var sourceIcon: String {
        switch estimate.source {
        case .catalog: "checkmark.seal.fill"
        case .usda: "leaf.fill"
        case .mixed: "checkmark.seal.fill"
        case .ai: "sparkles"
        }
    }

    private var sourceTint: Color {
        switch estimate.source {
        case .catalog, .usda: theme.colors.accentGreen
        case .mixed: Color(hex: "#FF9500")
        case .ai: Color(hex: "#FF9500")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            NutritionSourceBanner(source: estimate.source, label: estimate.sourceLabel)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(estimate.matchedName.isEmpty ? estimate.title : estimate.matchedName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)

                    if !estimate.servingDescription.isEmpty {
                        Text(estimate.servingDescription)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    Label(estimate.source.showsAICaution ? confidenceLabel : estimate.sourceLabel, systemImage: sourceIcon)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(sourceTint)
                }

                Spacer(minLength: 0)
            }

            NutritionMacroRangeView(
                title: "Calories",
                unit: "kcal",
                range: estimate.calories,
                tint: Color(hex: "#FF9500"),
                progress: calorieProgress
            )

            NutritionMacroRangeView(
                title: "Protein",
                unit: "g",
                range: estimate.protein,
                tint: theme.colors.accentGreen,
                progress: proteinProgress
            )

            if !estimate.assumptions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ASSUMPTIONS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.colors.textSecondary)

                    ForEach(estimate.assumptions, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("·")
                                .foregroundStyle(theme.colors.textTertiary)
                            Text(item)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Text("Estimates only — not medical or dietary advice.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textTertiary)
        }
        .padding(HabfitiseSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HabfitiseRadius.lg, style: .continuous)
                .fill(theme.colors.fieldBackground)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Ingredient row

struct NutritionIngredientRow: View {
    @Binding var row: NutritionIngredientDraft
    let canDelete: Bool
    let onDelete: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            TextField("Ingredient", text: $row.name)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)
                .padding(.horizontal, HabfitiseSpacing.md)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: HabfitiseRadius.md, style: .continuous)
                        .fill(theme.colors.chipBackground)
                )

            TextField("Amt", value: $row.amount, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(width: 52)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: HabfitiseRadius.md, style: .continuous)
                        .fill(theme.colors.chipBackground)
                )

            Menu {
                ForEach(NutritionIngredientUnit.allCases) { unit in
                    Button(unit.label) { row.unit = unit.label }
                }
            } label: {
                Text(row.unit)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(width: 52)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: HabfitiseRadius.md, style: .continuous)
                            .fill(theme.colors.chipBackground)
                    )
            }

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(theme.colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Meal log row

struct NutritionMealRow: View {
    let log: FoodLog

    @Environment(ThemeManager.self) private var theme

    private var timeLabel: String {
        log.loggedAt.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2)

                Text(timeLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textTertiary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(log.caloriesMid) kcal")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#FF9500"))
                Text("\(log.proteinMid)g protein")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .padding(.vertical, HabfitiseSpacing.sm)
    }
}

// MARK: - Dual ring (home card)

struct NutritionDualRingView: View {
    let calorieProgress: Double
    let proteinProgress: Double
    let calorieTint: Color
    let proteinTint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                .frame(width: 72, height: 72)

            Circle()
                .trim(from: 0, to: min(max(calorieProgress, 0), 1))
                .stroke(calorieTint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 72, height: 72)

            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 6)
                .frame(width: 48, height: 48)

            Circle()
                .trim(from: 0, to: min(max(proteinProgress, 0), 1))
                .stroke(proteinTint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 48, height: 48)

            Image(systemName: "fork.knife")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(calorieTint)
        }
        .accessibilityHidden(true)
    }
}
