import SwiftUI

// MARK: - Fixed onboarding palette (always dark — independent of app theme)

enum OnboardingPalette {
    static let background = Color(hex: "#1A1A1A")
    static let card = Color(hex: "#2A2A2A")
    static let accent = Color(hex: "#22C55E")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#9CA3AF")
    static let textMuted = Color.white.opacity(0.7)
    static let goalCardBackground = Color(hex: "#1A1A1A")
    static let goalCardBorder = Color.white.opacity(0.1)
    static let goalSelectedBackground = Color(hex: "#22C55E").opacity(0.15)
    static let chipUnselected = Color(hex: "#1A1A1A")
    static let chipSelected = Color(hex: "#22C55E")
    static let stepperBackground = Color(hex: "#1A1A1A")
    static let stepperButton = Color(hex: "#2A2A2A")
    static let inactiveDot = Color(hex: "#333333")
    static let summaryBackground = Color(hex: "#22C55E").opacity(0.1)
    static let summaryRate = Color(hex: "#22C55E").opacity(0.7)
    static let weekdayUnselected = Color(hex: "#2A2A2A")
}

// MARK: - Onboarding Card Shell

struct OnboardingBottomCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .top)
            .background(OnboardingPalette.card)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
            )
    }
}

// MARK: - Progress Dots

struct OnboardingProgressDots: View {
    let activeIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == activeIndex ? OnboardingPalette.accent : OnboardingPalette.inactiveDot)
                    .frame(width: index == activeIndex ? 10 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeIndex)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Continue Button

struct OnboardingContinueButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isEnabled ? OnboardingPalette.accent : OnboardingPalette.accent.opacity(0.4))
                )
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(hapticOnPress: true))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

// MARK: - Name Field

struct OnboardingNameField: View {
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your name")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingPalette.textSecondary)

            TextField("What should we call you?", text: $name)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(OnboardingPalette.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(OnboardingPalette.stepperBackground)
                )
        }
    }
}

// MARK: - Goal Card

struct OnboardingGoalCard: View {
    let goal: OnboardingGoalOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: goal.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? OnboardingPalette.accent : OnboardingPalette.textSecondary)
                    .frame(width: 24)

                Text(goal.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingPalette.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? OnboardingPalette.goalSelectedBackground : OnboardingPalette.goalCardBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? OnboardingPalette.accent : OnboardingPalette.goalCardBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weight Stepper Row

struct OnboardingWeightStepper: View {
    let label: String
    let value: Double
    let unit: WeightUnit
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingPalette.textSecondary)

            HStack(spacing: 0) {
                stepperButton(systemName: "minus", action: onDecrement)

                Text(String(format: "%.0f", value))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingPalette.textPrimary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                stepperButton(systemName: "plus", action: onIncrement)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(OnboardingPalette.stepperBackground)
            )
        }
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingPalette.textPrimary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(OnboardingPalette.stepperButton)
                )
        }
        .buttonStyle(HabfitiseScalePressButtonStyle())
        .padding(.horizontal, 6)
    }
}

// MARK: - Capsule Toggle Group

struct OnboardingCapsuleToggleGroup<T: Hashable & Identifiable>: View where T: CaseIterable, T.AllCases: RandomAccessCollection {
    let title: String?
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(OnboardingPalette.textSecondary)
            }

            HStack(spacing: 8) {
                ForEach(Array(T.allCases)) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = option
                        }
                    } label: {
                        Text(label(option))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(selection == option ? .white : OnboardingPalette.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selection == option ? OnboardingPalette.chipSelected : OnboardingPalette.chipUnselected)
                            )
                    }
                    .buttonStyle(HabfitiseScalePressButtonStyle())
                }
            }
        }
    }
}

// MARK: - Unit Toggle (kg/lbs)

struct OnboardingUnitToggle: View {
    @Binding var unit: WeightUnit

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WeightUnit.allCases, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        unit = option
                    }
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(unit == option ? .white : OnboardingPalette.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(unit == option ? OnboardingPalette.chipSelected : OnboardingPalette.chipUnselected)
                        )
                }
                .buttonStyle(HabfitiseScalePressButtonStyle())
            }
        }
    }
}

// MARK: - Goal Summary Card

struct OnboardingGoalSummaryCard: View {
    let summary: OnboardingGoalSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.headline)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(OnboardingPalette.accent)
            if let detail = summary.detail {
                Text(detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(OnboardingPalette.summaryRate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(OnboardingPalette.summaryBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(OnboardingPalette.accent, lineWidth: 1)
        }
    }
}

// MARK: - Weekday Toggles

struct OnboardingWeekdayPicker: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days per week")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingPalette.textSecondary)

            HStack(spacing: 8) {
                ForEach(Weekday.allCases) { day in
                    let isSelected = viewModel.selectedWeekdays.contains(day.rawValue)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.toggleWeekday(day.rawValue)
                        }
                    } label: {
                        Text(day.shortLabel)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : OnboardingPalette.textSecondary)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(isSelected ? OnboardingPalette.accent : OnboardingPalette.weekdayUnselected)
                            )
                    }
                    .buttonStyle(HabfitiseScalePressButtonStyle())
                }
            }
        }
    }
}

// MARK: - Water Stepper

struct OnboardingWaterStepper: View {
    @Bindable var viewModel: OnboardingViewModel

    private var formattedGoal: String {
        viewModel.dailyWaterGoalML.formatted(.number.grouping(.automatic)) + " ml"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily water goal")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingPalette.textSecondary)

            HStack(spacing: 0) {
                stepperButton(systemName: "minus") {
                    viewModel.adjustWaterGoal(by: -250)
                }

                Text(formattedGoal)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingPalette.textPrimary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                stepperButton(systemName: "plus") {
                    viewModel.adjustWaterGoal(by: 250)
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(OnboardingPalette.stepperBackground)
            )
        }
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingPalette.textPrimary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(OnboardingPalette.stepperButton)
                )
        }
        .buttonStyle(HabfitiseScalePressButtonStyle())
        .padding(.horizontal, 6)
    }
}

// MARK: - Building Plan Loading

struct OnboardingBuildingPlanView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(OnboardingPalette.accent)

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingPalette.textSecondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: message)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

// MARK: - Section Headers

struct OnboardingSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingPalette.textPrimary)
            Text(subtitle)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(OnboardingPalette.textSecondary)
        }
    }
}

struct OnboardingStepTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingPalette.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(OnboardingPalette.textSecondary)
            }
        }
    }
}

// MARK: - App Icon

struct OnboardingAppIcon: View {
    var body: some View {
        Text("HF")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(OnboardingPalette.accent)
            )
    }
}
