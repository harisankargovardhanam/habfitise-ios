import SwiftUI

struct HabfitiseThemePreview: View {
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                    Text("Habfitise")
                        .font(HabfitiseTypography.largeTitle)
                        .foregroundStyle(theme.colors.textOnBackground)

                    Text("Design system preview")
                        .font(HabfitiseTypography.callout)
                        .foregroundStyle(theme.colors.textMutedOnBackground)
                }

                HabfitiseCard {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                        HabfitiseSectionLabel(text: "Typography")

                        Text("Primary body text")
                            .font(HabfitiseTypography.body)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("Secondary supporting copy")
                            .font(HabfitiseTypography.subheadline)
                            .foregroundStyle(theme.colors.textSecondary)

                        Text("2,450 ml")
                            .font(HabfitiseTypography.numericStat)
                            .foregroundStyle(theme.colors.waterBlue)

                        Text("78%")
                            .font(HabfitiseTypography.numericPercentage)
                            .foregroundStyle(theme.colors.percentageOrange)
                    }
                }

                HabfitiseCard {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                        HabfitiseSectionLabel(text: "Actions")

                        HabfitisePrimaryButton(title: "Start Workout") {}

                        HabfitisePrimaryButton(title: "Disabled", isEnabled: false) {}
                    }
                }

                HabfitiseCard {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                        HabfitiseSectionLabel(text: "Chips")

                        HStack(spacing: HabfitiseSpacing.md) {
                            Text("Default")
                                .habfitiseChipStyle(
                                    color: theme.colors.chipBackground,
                                    textColor: theme.colors.textPrimary
                                )

                            Text("Done")
                                .habfitiseChipStyle(
                                    color: theme.colors.chipDone,
                                    textColor: theme.colors.accentGreen
                                )

                            Text("Today")
                                .habfitiseChipStyle(
                                    color: theme.colors.chipToday,
                                    textColor: theme.colors.textPrimary
                                )

                            Text("Tomorrow")
                                .habfitiseChipStyle(
                                    color: theme.colors.chipTomorrow,
                                    textColor: theme.colors.waterBlue
                                )
                        }

                        Text("12 day streak")
                            .habfitiseChipStyle(
                                color: theme.colors.streakPill,
                                textColor: theme.colors.percentageOrange
                            )
                    }
                }

                HabfitiseCard {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                        HabfitiseSectionLabel(text: "Semantic Colors")

                        HStack(spacing: HabfitiseSpacing.xxl) {
                            colorSwatch("Accent", theme.colors.accentGreen)
                            colorSwatch("Water", theme.colors.waterBlue)
                            colorSwatch("Danger", theme.colors.danger)
                        }
                    }
                }

                HabfitiseCard {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                        HabfitiseSectionLabel(text: "Bar Chart")

                        HStack(alignment: .bottom, spacing: HabfitiseSpacing.lg) {
                            ForEach([0.4, 0.7, 1.0, 0.55, 0.85, 0.3, 0.65], id: \.self) { value in
                                HabfitiseCapsuleBar(
                                    value: value,
                                    maxValue: 1.0,
                                    color: theme.colors.accentGreen
                                )
                                .frame(width: 20, height: 80)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, HabfitiseSpacing.xxl)
            .padding(.top, HabfitiseSpacing.xxxl)
            .padding(.bottom, HabfitiseSpacing.xxxl)
        }
        .habfitiseGreenBackground()
        .habfitiseWatermark()
    }

    private func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: HabfitiseSpacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
            Text(name)
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }
}

struct HabfitiseThemePreview_Previews: PreviewProvider {
    static var previews: some View {
        HabfitiseThemePreview()
            .environment(ThemeManager())
            .previewDisplayName("Habfitise Theme")
    }
}
