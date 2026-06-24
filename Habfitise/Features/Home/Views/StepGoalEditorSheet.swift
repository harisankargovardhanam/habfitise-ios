import SwiftUI

struct StepGoalEditorSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var goal: Int
    let onSave: (Int) -> Void

    private let presets = [6_000, 8_000, 10_000, 12_000, 15_000]

    init(currentGoal: Int, onSave: @escaping (Int) -> Void) {
        _goal = State(initialValue: currentGoal)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
                        Text("Daily step target")
                            .font(HabfitiseTypography.caption)
                            .foregroundStyle(theme.colors.textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(goal.formatted())")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.colors.textPrimary)
                                .contentTransition(.numericText())

                            Text("steps")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }

                    Slider(
                        value: Binding(
                            get: { Double(goal) },
                            set: { goal = Int($0.rounded()) }
                        ),
                        in: 3_000...20_000,
                        step: 500
                    )
                    .tint(Color(hex: "#FF375F"))

                    VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                        Text("Quick picks")
                            .font(HabfitiseTypography.caption)
                            .foregroundStyle(theme.colors.textSecondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        goal = preset
                                    }
                                } label: {
                                    Text(preset.formatted())
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(goal == preset ? theme.colors.textOnBackground : theme.colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(goal == preset ? Color(hex: "#FF375F") : theme.colors.chipBackground)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(HabfitiseSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(theme.colors.cardBackground)
            .navigationTitle("Step Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(goal)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
