import SwiftUI
import SwiftData

struct AddFoodView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var viewModel: NutritionViewModel
    let userId: String
    let onSaved: () -> Void

    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case foodName
        case ingredient(UUID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                modePicker

                if viewModel.inputMode == .foodName {
                    foodNameSection
                    portionSection
                } else {
                    ingredientsSection
                }

                if let error = viewModel.estimateError {
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "#FF453A"))
                }

                if let estimate = viewModel.pendingEstimate {
                    NutritionEstimateResultCard(
                        estimate: estimate,
                        calorieProgress: progress(for: estimate.calories.mid, target: viewModel.daySummary.calorieTarget),
                        proteinProgress: progress(for: estimate.protein.mid, target: viewModel.daySummary.proteinTarget)
                    )
                }
            }
            .padding(HabfitiseSpacing.xxl)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(theme.colors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .navigationTitle("Log Food")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.pendingEstimate) { _, estimate in
            if estimate != nil {
                dismissKeyboard()
            }
        }
        .onChange(of: viewModel.isEstimating) { _, estimating in
            if estimating {
                dismissKeyboard()
            }
        }
    }

    private var modePicker: some View {
        Picker("Input mode", selection: $viewModel.inputMode) {
            ForEach(FoodLogInputMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.inputMode) { _, _ in
            viewModel.pendingEstimate = nil
            viewModel.estimateError = nil
        }
    }

    private var foodNameSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("What did you eat?")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            TextField("e.g. Chicken biryani with raita", text: $viewModel.foodName, axis: .vertical)
                .focused($focusedField, equals: .foodName)
                .lineLimit(2...4)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)
                .padding(HabfitiseSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: HabfitiseRadius.lg, style: .continuous)
                        .fill(theme.colors.chipBackground)
                )
                .submitLabel(.done)
                .onSubmit { dismissKeyboard() }

            Text("AI returns a calorie and protein range — not an exact count.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textTertiary)
        }
    }

    private var portionSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("Portion size")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            NutritionPortionPicker(selection: $viewModel.portionSize)
                .onChange(of: viewModel.portionSize) { _, _ in
                    viewModel.pendingEstimate = nil
                    viewModel.estimateError = nil
                }

            Text(viewModel.portionSize.subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textTertiary)
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            Text("Build your plate")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            ForEach($viewModel.ingredientRows) { $row in
                NutritionIngredientRow(
                    row: $row,
                    canDelete: viewModel.ingredientRows.count > 1,
                    onDelete: { viewModel.removeIngredientRow(row.id) }
                )
            }

            Button {
                viewModel.addIngredientRow()
            } label: {
                Label("Add ingredient", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.accentGreen)
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(theme.colors.cardBorder)

            VStack(spacing: HabfitiseSpacing.md) {
                if viewModel.pendingEstimate == nil {
                    estimateButton
                } else {
                    HabfitisePrimaryButton(title: "Save to Today") {
                        viewModel.saveEstimate(userId: userId, context: modelContext)
                        onSaved()
                        dismiss()
                    }

                    Button("Estimate again") {
                        viewModel.pendingEstimate = nil
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .padding(.horizontal, HabfitiseSpacing.xxl)
            .padding(.top, HabfitiseSpacing.lg)
            .padding(.bottom, HabfitiseSpacing.lg)
        }
        .background(.ultraThinMaterial)
    }

    private var estimateButton: some View {
        Button {
            dismissKeyboard()
            Task { await viewModel.estimateWithAI(appState: appState) }
        } label: {
            HStack(spacing: HabfitiseSpacing.sm) {
                if viewModel.isEstimating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(viewModel.isEstimating ? "Estimating…" : "Estimate with AI")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: HabfitiseRadius.full, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF9F0A"), Color(hex: "#FF6723")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.98))
        .disabled(viewModel.isEstimating)
    }

    private func progress(for value: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return Double(value) / Double(target)
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}
