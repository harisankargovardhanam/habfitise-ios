import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                OnboardingPalette.background
                    .ignoresSafeArea()

                OnboardingWatermark()
                    .padding(.top, 8)
                    .padding(.trailing, 16)

                if viewModel.step == 0 {
                    welcomeScreen
                } else {
                    stepsWithCard(height: geometry.size.height)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
    }

    // MARK: - Step 1 Welcome (full screen)

    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            HabfitiseLogoView(height: 120, maxWidth: 240)
                .padding(.horizontal, 32)

            Text("Your workout, habits, and day — one app.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(OnboardingPalette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)

            Spacer()
                .frame(height: 32)

            VStack(spacing: 12) {
                OnboardingContinueButton(title: "Get started") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        viewModel.nextStep()
                    }
                }

                Button {
                    Task { await viewModel.signOutExistingAccount(appState: appState) }
                } label: {
                    Text("I have an account")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(OnboardingPalette.accent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HabfitiseScalePressButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Steps 2–4 (dark card bottom 65%)

    private func stepsWithCard(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            onboardingCard
                .frame(height: height * 0.65)
        }
    }

    private var onboardingCard: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(activeIndex: viewModel.step, total: viewModel.totalSteps)
                .padding(.top, 24)
                .padding(.bottom, 20)

            if viewModel.isBuildingPlan {
                OnboardingBuildingPlanView(message: viewModel.loadingMessages[viewModel.loadingMessageIndex])
                    .transition(.opacity)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        stepContent
                            .opacity(viewModel.cardContentVisible ? 1 : 0)
                            .offset(y: viewModel.cardContentVisible ? 0 : -20)

                        if let buildError = viewModel.buildError {
                            Text(buildError)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(OnboardingPalette.accent.opacity(0.9))
                        }

                        primaryAction
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OnboardingPalette.card)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24
            )
        )
        .animation(.easeOut(duration: 0.3), value: viewModel.cardContentVisible)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.step)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case 1:
            goalStep
        case 2:
            weightStep
        case 3:
            scheduleStep
        default:
            EmptyView()
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingSectionHeader(
                title: "What's your goal?",
                subtitle: "We'll build your plan around this"
            )

            VStack(spacing: 10) {
                ForEach(OnboardingGoalOption.allCases) { goal in
                    OnboardingGoalCard(
                        goal: goal,
                        isSelected: viewModel.selectedGoal == goal
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedGoal = goal
                        }
                    }
                }
            }
        }
    }

    private var weightStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingStepTitle(title: "Set your target")

            HStack(alignment: .top, spacing: 12) {
                OnboardingWeightStepper(
                    label: "Your current weight",
                    value: viewModel.displayCurrentWeight,
                    unit: viewModel.weightUnit,
                    onDecrement: viewModel.decrementCurrentWeight,
                    onIncrement: viewModel.incrementCurrentWeight
                )

                OnboardingUnitToggle(unit: $viewModel.weightUnit)
                    .padding(.top, 24)
            }

            OnboardingWeightStepper(
                label: "Target weight",
                value: viewModel.displayTargetWeight,
                unit: viewModel.weightUnit,
                onDecrement: viewModel.decrementTargetWeight,
                onIncrement: viewModel.incrementTargetWeight
            )

            OnboardingCapsuleToggleGroup(
                title: "Reach goal by",
                selection: $viewModel.timeline,
                label: \.label
            )

            OnboardingGoalSummaryCard(summary: viewModel.goalSummary)
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingStepTitle(title: "When do you train?")

            OnboardingWeekdayPicker(viewModel: viewModel)

            OnboardingCapsuleToggleGroup(
                title: "Preferred time",
                selection: $viewModel.preferredTime,
                label: \.label
            )

            OnboardingCapsuleToggleGroup(
                title: "Equipment",
                selection: $viewModel.equipment,
                label: \.label
            )

            OnboardingWaterStepper(viewModel: viewModel)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var primaryAction: some View {
        switch viewModel.step {
        case 1, 2:
            OnboardingContinueButton(title: "Continue", isEnabled: viewModel.canContinue) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    viewModel.nextStep()
                }
            }

        case 3:
            OnboardingContinueButton(title: "Build my plan →", isEnabled: viewModel.canContinue) {
                Task {
                    await viewModel.buildMyPlan(appState: appState, syncService: syncService, context: modelContext)
                }
            }

        default:
            EmptyView()
        }
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environment(AppState())
            .environment(SyncService())
            .environment(ThemeManager())
    }
}
#endif
