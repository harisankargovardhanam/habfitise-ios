import SwiftUI
import SwiftData

// MARK: - Inline banner (Home + Workout Hub)

struct MissedWorkoutBanner: View {
    let templateName: String
    let scheduledDate: Date
    let onPushTomorrow: () -> Void
    let onSkip: () -> Void

    private let missedRed = Color(hex: "#FF4444")
    private let mutedText = Color(hex: "#9CA3AF")
    private let skipBackground = Color(hex: "#2A2A2A")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(missedRed)
                        .frame(width: 8, height: 8)
                    Text("Missed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(missedRed)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(missedRed.opacity(0.12)))
            }

            Text(templateName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(missedRed)

            Text(scheduledDate.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 14))
                .foregroundStyle(missedRed.opacity(0.85))

            Text("What would you like to do?")
                .font(.system(size: 13))
                .foregroundStyle(mutedText)

            HStack(spacing: 10) {
                Button(action: onPushTomorrow) {
                    Text("Push to tomorrow")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color(hex: "#22C55E")))
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Text("Skip this week")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(skipBackground))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(missedRed.opacity(0.08))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(missedRed)
                        .frame(width: 3)
                }
        )
    }
}

// MARK: - Proactive bottom sheet

private enum MissedWorkoutSheetOption: String, CaseIterable, Identifiable {
    case pushTomorrow
    case pickDay
    case skipWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pushTomorrow: "📅 Push to tomorrow"
        case .pickDay: "📅 Pick another day"
        case .skipWeek: "⏭ Skip for this week"
        }
    }

    var subtitle: String {
        switch self {
        case .pushTomorrow: "We'll add it to tomorrow's schedule"
        case .pickDay: "Choose when works for you"
        case .skipWeek: "No worries — see you next session"
        }
    }
}

struct MissedWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: MissedWorkoutSheetItem
    let onConfirm: () -> Void
    let onDismissWithoutConfirm: () -> Void

    @State private var selectedOption: MissedWorkoutSheetOption = .pushTomorrow
    @State private var pickedDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now

    @State private var didConfirm = false

    private let sheetBackground = Color(hex: "#111111")
    private let cardBackground = Color(hex: "#1A1A1A")
    private let mutedText = Color(hex: "#9CA3AF")
    private let accentGreen = Color(hex: "#22C55E")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.prompt)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.template.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(item.missed.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14))
                    .foregroundStyle(mutedText)
            }

            VStack(spacing: 12) {
                ForEach(MissedWorkoutSheetOption.allCases) { option in
                    optionCard(option)
                }
            }

            if selectedOption == .pickDay {
                DatePicker(
                    "Reschedule",
                    selection: $pickedDate,
                    in: Calendar.current.startOfDay(for: .now)...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(accentGreen)
                .colorScheme(.dark)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cardBackground)
                )
            }

            Button {
                confirmSelection()
            } label: {
                Text("Confirm")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accentGreen))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sheetBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            if !didConfirm {
                onDismissWithoutConfirm()
            }
        }
    }

    @ViewBuilder
    private func optionCard(_ option: MissedWorkoutSheetOption) -> some View {
        let isSelected = selectedOption == option

        Button {
            selectedOption = option
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(option.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor(for: option, selected: isSelected), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func borderColor(for option: MissedWorkoutSheetOption, selected: Bool) -> Color {
        guard selected else { return Color(hex: "#2A2A2A") }
        switch option {
        case .skipWeek: return Color(hex: "#6B7280")
        case .pushTomorrow, .pickDay: return accentGreen
        }
    }

    private func confirmSelection() {
        let response: MissedWorkoutResponse
        switch selectedOption {
        case .pushTomorrow:
            response = .pushTomorrow
        case .pickDay:
            response = .reschedule(pickedDate)
        case .skipWeek:
            response = .skip
        }

        MissedWorkoutService.shared.resolve(
            missed: item.missed,
            template: item.template,
            response: response,
            context: modelContext
        )
        didConfirm = true
        onConfirm()
        dismiss()
    }
}
