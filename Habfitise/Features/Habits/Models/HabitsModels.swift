import Foundation
import SwiftUI

struct HabitDayItem: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let weekdayLabel: String
    let isCompleted: Bool
    let isToday: Bool
    let isFuture: Bool
}

struct HabitColorOption: Identifiable, Equatable {
    let id: String
    let hex: String
    let name: String

    var color: Color { Color(hex: "#\(hex)") }

    static let palette: [HabitColorOption] = [
        HabitColorOption(id: "green", hex: "22C55E", name: "Green"),
        HabitColorOption(id: "coral", hex: "FF6B35", name: "Coral"),
        HabitColorOption(id: "blue", hex: "3B82F6", name: "Blue"),
        HabitColorOption(id: "purple", hex: "8B5CF6", name: "Purple"),
        HabitColorOption(id: "amber", hex: "FBBF24", name: "Amber"),
        HabitColorOption(id: "teal", hex: "14B8A6", name: "Teal")
    ]
}

enum HabitFrequencyMode: String, CaseIterable, Identifiable {
    case daily
    case specificDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: "Daily"
        case .specificDays: "Specific days"
        }
    }
}

enum WeekdaySelection: Int, CaseIterable, Identifiable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        case .sunday: "S"
        }
    }

    var storageKey: String {
        switch self {
        case .monday: "mon"
        case .tuesday: "tue"
        case .wednesday: "wed"
        case .thursday: "thu"
        case .friday: "fri"
        case .saturday: "sat"
        case .sunday: "sun"
        }
    }
}

enum HabitStreakMilestone {
    static let values: Set<Int> = [7, 30, 100]

    static func isMilestone(_ streak: Int) -> Bool {
        values.contains(streak)
    }
}
