import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ProfileViewModel {
    var displayName = ""
    var age = 25
    var heightCm: Double = 170
    var weightKg: Double = 75
    var targetWeightKg: Double = 68
    var goalLabel = "Not set"
    var memberSince = Date.now
    var timeline: GoalTimeline = .sixMonths
    var daysPerWeek = 3

    var isSaving = false
    var didSave = false

    private var userId = ""

    func load(profile: UserProfile?, userId: String) {
        self.userId = userId
        guard let profile else { return }

        displayName = profile.displayName
        age = profile.age > 0 ? profile.age : 25
        heightCm = profile.heightCm > 0 ? profile.heightCm : 170
        weightKg = profile.weightKg
        targetWeightKg = profile.targetWeightKg > 0 ? profile.targetWeightKg : 68
        memberSince = profile.createdAt
        timeline = Self.timeline(from: profile.goalDeadline, reference: profile.createdAt)
        daysPerWeek = Self.loadDaysPerWeek(userId: userId)

        if let goal = OnboardingGoalOption(rawValue: profile.goal) {
            goalLabel = goal.title
        } else if !profile.goal.isEmpty {
            goalLabel = profile.goal.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    func save(profile: UserProfile?, context: ModelContext) {
        guard let profile else { return }

        isSaving = true
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.age = age
        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.targetWeightKg = targetWeightKg
        profile.goalDeadline = timeline.deadline(from: memberSince)
        profile.synced = false
        profile.updatedAt = .now

        Self.saveDaysPerWeek(daysPerWeek, userId: userId)

        try? context.save()
        isSaving = false
        didSave = true
    }

    var firstInitial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    var memberSinceLabel: String {
        "Since \(Self.memberSinceFormatter.string(from: memberSince))"
    }

    var goalSubtitle: String {
        "Goal: \(goalLabel)"
    }

    var targetWeightLabel: String {
        String(format: "%.1f kg", targetWeightKg)
    }

    var timelineLabel: String {
        timeline.label
    }

    var daysPerWeekLabel: String {
        "\(daysPerWeek) day\(daysPerWeek == 1 ? "" : "s") / week"
    }

    private static let memberSinceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, ''yy"
        return formatter
    }()

    private static func timeline(from deadline: Date, reference: Date) -> GoalTimeline {
        let months = Calendar.current.dateComponents([.month], from: reference, to: deadline).month ?? 6
        switch months {
        case ...4: return .threeMonths
        case 5...9: return .sixMonths
        default: return .oneYear
        }
    }

    private static func daysPerWeekKey(userId: String) -> String {
        "trainingDaysPerWeek_\(userId)"
    }

    private static func loadDaysPerWeek(userId: String) -> Int {
        let stored = UserDefaults.standard.integer(forKey: daysPerWeekKey(userId: userId))
        return stored > 0 ? stored : 3
    }

    private static func saveDaysPerWeek(_ days: Int, userId: String) {
        UserDefaults.standard.set(days, forKey: daysPerWeekKey(userId: userId))
    }
}

private extension GoalTimeline {
    func deadline(from reference: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: monthCount, to: reference) ?? reference
    }
}
