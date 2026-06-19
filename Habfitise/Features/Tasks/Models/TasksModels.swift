import Foundation
import SwiftUI

enum TaskRecurrence: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    init(stored: String?) {
        guard let stored, let value = TaskRecurrence(rawValue: stored) else {
            self = .none
            return
        }
        self = value
    }
}

enum TaskQuickDate: String, CaseIterable, Identifiable {
    case today
    case tomorrow
    case pickDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .pickDate: "Pick date"
        }
    }
}

struct TaskDueChipStyle: Equatable {
    let label: String
    let background: Color
    let foreground: Color

    static func style(for dueDate: Date?, isComplete: Bool, colors: ThemeColors) -> TaskDueChipStyle {
        guard let dueDate else {
            return TaskDueChipStyle(
                label: "Someday",
                background: colors.chipBackground,
                foreground: colors.textTertiary
            )
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dueDay = calendar.startOfDay(for: dueDate)

        if isComplete {
            return TaskDueChipStyle(
                label: dueDate.formattedRelativeDay(),
                background: colors.chipDone,
                foreground: colors.accentGreen
            )
        }

        if dueDay < today {
            return TaskDueChipStyle(
                label: "Overdue",
                background: Color(hex: "#FEE2E2"),
                foreground: colors.danger
            )
        }

        if calendar.isDateInToday(dueDate) {
            let time = Calendar.current.component(.hour, from: dueDate) == 0
                && Calendar.current.component(.minute, from: dueDate) == 0
                ? "Today"
                : "Today · \(dueDate.formattedTime())"
            return TaskDueChipStyle(
                label: time,
                background: colors.chipToday,
                foreground: colors.textPrimary
            )
        }

        if calendar.isDateInTomorrow(dueDate) {
            return TaskDueChipStyle(
                label: "Tomorrow",
                background: colors.chipTomorrow,
                foreground: colors.waterBlue
            )
        }

        let days = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        if days <= 7 {
            return TaskDueChipStyle(
                label: dueDate.formatted(.dateTime.weekday(.abbreviated)),
                background: colors.chipBackground,
                foreground: colors.textSecondary
            )
        }

        return TaskDueChipStyle(
            label: dueDate.formatted(.dateTime.month(.abbreviated).day()),
            background: colors.chipBackground,
            foreground: colors.textSecondary
        )
    }
}

enum TaskSection: String, CaseIterable, Identifiable {
    case today
    case upcoming
    case someday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .someday: "Someday"
        }
    }
}
