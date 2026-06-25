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
        .onChange(of: viewModel.foodName) { _, _ in
            viewModel.pendingEstimate = nil
            viewModel.estimateError = nil
        }
        .onChange(of: viewModel.ingredientRows.map(\.name)) { _, _ in
            viewModel.pendingEstimate = nil
            viewModel.estimateError = nil
        }
    }

    private var foodNameSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("What did you eat?")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            TextField("e.g. 1 cup tea with sugar, 2 eggs, chicken biryani", text: $viewModel.foodName, axis: .vertical)
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

            Text("We check our food database first. Include an amount when you can (1 cup, 2 slices).")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textTertiary)

            if viewModel.showsMilkTeaDefaultHint {
                Label("Tea is estimated as milk tea (chai). Say \"black tea\" if without milk.", systemImage: "info.circle")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

                    Button("Look up again") {
                        viewModel.clearPendingLookup()
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
            Task { await viewModel.resolveNutrition(appState: appState) }
        } label: {
            HStack(spacing: HabfitiseSpacing.sm) {
                if viewModel.isEstimating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: viewModel.inputMode == .ingredients ? "sparkles" : "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(viewModel.isEstimating ? "Looking up…" : lookupButtonTitle)
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

    private var lookupButtonTitle: String {
        switch viewModel.inputMode {
        case .foodName: "Look up food"
        case .ingredients: "Estimate with AI"
        }
    }

    private func progress(for value: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return Double(value) / Double(target)
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}
