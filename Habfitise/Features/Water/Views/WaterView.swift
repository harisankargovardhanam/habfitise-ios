import SwiftUI

struct WaterView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var viewModel = WaterViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                Text("Water")
                    .font(HabfitiseTypography.title2)
                    .foregroundStyle(theme.colors.textOnBackground)

                HabfitiseCard {
                    VStack(spacing: HabfitiseSpacing.xxl) {
                        HStack {
                            VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
                                Text("\(viewModel.totalML) ml")
                                    .font(HabfitiseTypography.title)
                                Text("Goal: \(viewModel.goalML) ml")
                                    .font(HabfitiseTypography.caption)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                            Spacer()
                            WaterCupIcon(fillLevel: viewModel.fillLevel, size: 56)
                        }

                        HabfitisePrimaryButton(title: "Log \(AppConstants.Water.cupSizeML) ml") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                viewModel.logCup()
                            }
                        }
                    }
                }

                HabfitiseCard {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                        Text("This Week")
                            .font(HabfitiseTypography.headline)

                        HStack(alignment: .bottom, spacing: HabfitiseSpacing.md) {
                            ForEach(Array(viewModel.weeklyTotals.enumerated()), id: \.offset) { index, value in
                                VStack(spacing: HabfitiseSpacing.sm) {
                                    HabfitiseCapsuleBar(
                                        value: Double(value),
                                        maxValue: Double(viewModel.goalML),
                                        color: theme.colors.waterBlue
                                    )
                                    .frame(width: 24, height: 100)

                                    Text(["M", "T", "W", "T", "F", "S", "S"][index])
                                        .font(HabfitiseTypography.caption)
                                        .foregroundStyle(theme.colors.textSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, HabfitiseSpacing.xxl)
            .padding(.top, HabfitiseSpacing.xxl)
            .padding(.bottom, 100)
        }
        .onAppear { viewModel.refresh() }
    }
}
