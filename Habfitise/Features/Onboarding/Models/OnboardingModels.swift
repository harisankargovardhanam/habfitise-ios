import Foundation

// MARK: - Goal Options

enum OnboardingGoalOption: String, CaseIterable, Identifiable {
    case loseWeight = "lose_weight"
    case buildMuscle = "build_muscle"
    case improveFitness = "improve_fitness"
    case buildHabits = "build_habits"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseWeight: "Lose weight"
        case .buildMuscle: "Build muscle"
        case .improveFitness: "Improve fitness"
        case .buildHabits: "Build healthy habits"
        }
    }

    var systemImage: String {
        switch self {
        case .loseWeight: "flame.fill"
        case .buildMuscle: "dumbbell.fill"
        case .improveFitness: "figure.run"
        case .buildHabits: "checkmark.circle.fill"
        }
    }
}

// MARK: - Weight & Schedule Enums

enum WeightUnit: String, CaseIterable {
    case kg
    case lbs

    var label: String { rawValue }

    func display(_ valueKg: Double) -> Double {
        switch self {
        case .kg: valueKg
        case .lbs: valueKg * 2.20462
        }
    }

    func toKilograms(_ displayValue: Double) -> Double {
        switch self {
        case .kg: displayValue
        case .lbs: displayValue / 2.20462
        }
    }
}

enum GoalTimeline: String, CaseIterable, Identifiable {
    case threeMonths
    case sixMonths
    case oneYear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        }
    }

    var monthCount: Int {
        switch self {
        case .threeMonths: 3
        case .sixMonths: 6
        case .oneYear: 12
        }
    }

    var deadline: Date {
        Calendar.current.date(byAdding: .month, value: monthCount, to: .now) ?? .now
    }
}

enum PreferredTrainingTime: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

enum TrainingEquipment: String, CaseIterable, Identifiable {
    case gym
    case home
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gym: "Gym"
        case .home: "Home"
        case .none: "None"
        }
    }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case monday = 0
    case tuesday = 1
    case wednesday = 2
    case thursday = 3
    case friday = 4
    case saturday = 5
    case sunday = 6

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }

    var apiKey: String {
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

// MARK: - Goal Summary

struct OnboardingGoalSummary {
    let headline: String
    let monthlyRate: String
}
