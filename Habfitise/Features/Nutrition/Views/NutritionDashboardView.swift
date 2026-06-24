import SwiftUI
import SwiftData

/// Full-screen nutrition hub — today's meals, goals, and AI logging.
struct NutritionDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var viewModel: NutritionViewModel
    let userId: String
    var startOnAdd: Bool = false

    @Query private var foodLogs: [FoodLog]
    @Query private var profiles: [UserProfile]

    @State private var showAddFood = false

    init(viewModel: NutritionViewModel, userId: String, startOnAdd: Bool = false) {
        self.viewModel = viewModel
        self.userId = userId
        self.startOnAdd = startOnAdd

        let normalized = userId.lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)

        _foodLogs = Query(
            filter: #Predicate<FoodLog> { log in
                log.userId == normalized && log.loggedAt >= today && log.loggedAt < tomorrow
            },
            sort: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        _profiles = Query(
            filter: #Predicate<UserProfile> { $0.userId == normalized }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                    summaryHeader
                    macroCards

                    if foodLogs.isEmpty {
                        emptyState
                    } else {
                        mealsSection
                    }
                }
                .padding(.horizontal, HabfitiseSpacing.lg)
                .padding(.top, HabfitiseSpacing.md)
                .padding(.bottom, HabfitiseSpacing.xxxl)
            }
            .scrollIndicators(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.colors.accentGreen)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.resetDraft()
                        showAddFood = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color(hex: "#FF9500"))
                    }
                    .accessibilityLabel("Log food")
                }
            }
            .navigationDestination(isPresented: $showAddFood) {
                AddFoodView(viewModel: viewModel, userId: userId) {
                    showAddFood = false
                }
            }
        }
        .onAppear {
            refreshSummary()
            if startOnAdd {
                viewModel.resetDraft()
                showAddFood = true
            }
        }
        .onChange(of: foodLogs.map(\.id)) { _, _ in
            refreshSummary()
        }
    }

    private func refreshSummary() {
        viewModel.refresh(
            logs: foodLogs,
            profile: profiles.first,
            activeEnergyKcal: 0
        )
    }

    private var summaryHeader: some View {
        HStack(alignment: .center, spacing: HabfitiseSpacing.lg) {
            NutritionDualRingView(
                calorieProgress: calorieProgress,
                proteinProgress: proteinProgress,
                calorieTint: Color(hex: "#FF9500"),
                proteinTint: theme.colors.accentGreen
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(viewModel.daySummary.consumedCalories)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("kcal")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Text(viewModel.daySummary.balanceLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        viewModel.daySummary.isOverTarget
                            ? Color(hex: "#FF453A")
                            : theme.colors.accentGreen
                    )
            }
        }
        .padding(HabfitiseSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
    }

    private var macroCards: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            macroTile(
                title: "Calories",
                value: "\(viewModel.daySummary.consumedCalories)",
                goal: "\(viewModel.daySummary.calorieTarget)",
                unit: "kcal",
                tint: Color(hex: "#FF9500")
            )
            macroTile(
                title: "Protein",
                value: "\(viewModel.daySummary.consumedProtein)",
                goal: "\(viewModel.daySummary.proteinTarget)",
                unit: "g",
                tint: theme.colors.accentGreen
            )
        }
    }

    private func macroTile(title: String, value: String, goal: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.colors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                Text("/ \(goal) \(unit)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Capsule()
                .fill(theme.colors.trackBackground)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .scaleEffect(x: title == "Calories" ? calorieProgress : proteinProgress, anchor: .leading)
                }
                .frame(height: 6)
        }
        .padding(HabfitiseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.colors.cardBackground)
        )
    }

    private var emptyState: some View {
        VStack(spacing: HabfitiseSpacing.lg) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(hex: "#FF9500"))

            Text("No meals yet today")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary)

            Text("Describe what you ate or list ingredients — AI estimates calories and protein as a thoughtful range.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.resetDraft()
                showAddFood = true
            } label: {
                Text(appState.isPro ? "Log Food with AI" : "Unlock AI Nutrition")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(hex: "#FF9500")))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, HabfitiseSpacing.xxxl)
        .padding(.horizontal, HabfitiseSpacing.lg)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("TODAY")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.colors.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(foodLogs.enumerated()), id: \.element.id) { index, log in
                    NutritionMealRow(log: log)
                        .padding(.horizontal, HabfitiseSpacing.lg)
                        .padding(.vertical, HabfitiseSpacing.sm)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteLog(log, context: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                    if index < foodLogs.count - 1 {
                        Divider().overlay(theme.colors.cardBorder)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: BentoCardStyle.cornerRadius, style: .continuous)
                    .fill(theme.colors.cardBackground)
            )
        }
    }

    private var calorieProgress: Double {
        guard viewModel.daySummary.calorieTarget > 0 else { return 0 }
        return Double(viewModel.daySummary.consumedCalories) / Double(viewModel.daySummary.calorieTarget)
    }

    private var proteinProgress: Double {
        guard viewModel.daySummary.proteinTarget > 0 else { return 0 }
        return Double(viewModel.daySummary.consumedProtein) / Double(viewModel.daySummary.proteinTarget)
    }
}
