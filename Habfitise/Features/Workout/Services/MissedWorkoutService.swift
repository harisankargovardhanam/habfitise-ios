import Foundation
import Observation
import SwiftData

enum MissedWorkoutResponse: Equatable {
    case pushTomorrow
    case reschedule(Date)
    case skip
}

struct MissedWorkoutSheetItem: Identifiable, Equatable {
    let id: UUID
    let missed: MissedWorkout
    let template: WorkoutTemplate
    let prompt: String

    init(missed: MissedWorkout, template: WorkoutTemplate, prompt: String) {
        self.id = missed.id
        self.missed = missed
        self.template = template
        self.prompt = prompt
    }
}

@Observable
@MainActor
final class MissedWorkoutService {
    static let shared = MissedWorkoutService()

    var proactiveSheetItem: MissedWorkoutSheetItem?

    private let dismissedSheetsKey = "missedWorkoutDismissedSheetIDs"
    private let proactiveDelay: TimeInterval = 8 * 60 * 60

    private init() {}

    // MARK: - Detection

    func detectMissedWorkouts(userId: String, context: ModelContext) {
        guard !userId.isEmpty else { return }

        let now = Date()
        let userIdConst = userId
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate<WorkoutTemplate> { template in
                template.userId == userIdConst
                    && template.nextScheduledAt != nil
                    && template.nextScheduledAt! < now
            }
        )

        let overdueTemplates = (try? context.fetch(descriptor)) ?? []
        for template in overdueTemplates {
            guard let scheduledAt = template.nextScheduledAt else { continue }
            guard !hasCompletedSession(for: template, on: scheduledAt, context: context) else { continue }
            guard !hasPendingMissedRecord(
                userId: userId,
                templateId: template.id,
                scheduledDate: scheduledAt,
                context: context
            ) else { continue }

            let missed = MissedWorkout(
                userId: userId,
                templateId: template.id,
                scheduledDate: scheduledAt,
                action: .pending,
                synced: false
            )
            context.insert(missed)
            Task {
                await NotificationService.shared.scheduleMissedWorkoutReminder(missed: missed, template: template)
            }
        }

        try? context.save()
    }

    func evaluateProactiveSheet(userId: String, context: ModelContext, themeManager: ThemeManager) {
        guard proactiveSheetItem == nil else { return }

        let pending = SwiftDataStack.shared.fetchMissedWorkouts(userId: userId, status: .pending)
        let dismissed = dismissedSheetIDs()

        for missed in pending {
            guard !dismissed.contains(missed.id.uuidString) else { continue }
            guard Date() >= missed.scheduledDate.addingTimeInterval(proactiveDelay) else { continue }
            guard let template = fetchTemplate(id: missed.templateId, userId: userId, context: context) else { continue }

            proactiveSheetItem = MissedWorkoutSheetItem(
                missed: missed,
                template: template,
                prompt: themeManager.missedWorkoutPrompt(seed: missed.id)
            )
            return
        }
    }

    func dismissProactiveSheet(for missedId: UUID) {
        var dismissed = dismissedSheetIDs()
        dismissed.insert(missedId.uuidString)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedSheetsKey)
        proactiveSheetItem = nil
    }

    func clearProactiveSheet() {
        proactiveSheetItem = nil
    }

    // MARK: - Responses

    func resolve(
        missed: MissedWorkout,
        template: WorkoutTemplate,
        response: MissedWorkoutResponse,
        context: ModelContext
    ) {
        let calendar = Calendar.current

        switch response {
        case .pushTomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
            template.nextScheduledAt = tomorrow
            missed.action = .pushed
            missed.pushedToDate = tomorrow

        case .reschedule(let date):
            let day = calendar.startOfDay(for: date)
            template.nextScheduledAt = day
            missed.action = .pushed
            missed.pushedToDate = day

        case .skip:
            template.nextScheduledAt = nil
            missed.action = .skipped
            missed.pushedToDate = nil
        }

        missed.synced = false
        missed.updatedAt = .now
        template.synced = false
        template.updatedAt = .now

        var dismissed = dismissedSheetIDs()
        dismissed.insert(missed.id.uuidString)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedSheetsKey)

        try? context.save()
        proactiveSheetItem = nil

        Task {
            await NotificationService.shared.cancelMissedWorkoutReminder(missedId: missed.id)
            switch response {
            case .pushTomorrow, .reschedule:
                await NotificationService.shared.scheduleWorkoutReminder(template: template)
            case .skip:
                await NotificationService.shared.cancelWorkoutReminder(templateId: template.id)
            }
        }
    }

    // MARK: - Queries

    func fetchTemplate(id: UUID, userId: String, context: ModelContext) -> WorkoutTemplate? {
        let templateId = id
        let userIdConst = userId
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { template in
                template.id == templateId && template.userId == userIdConst
            }
        )
        return try? context.fetch(descriptor).first
    }

    private func hasCompletedSession(
        for template: WorkoutTemplate,
        on scheduledDate: Date,
        context: ModelContext
    ) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: scheduledDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }

        let templateId = template.id
        let userIdConst = template.userId
        let start = dayStart
        let end = dayEnd

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.userId == userIdConst
                    && session.templateId == templateId
                    && session.startedAt >= start
                    && session.startedAt < end
                    && session.completedAt != nil
            }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private func hasPendingMissedRecord(
        userId: String,
        templateId: UUID,
        scheduledDate: Date,
        context: ModelContext
    ) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: scheduledDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }

        let userIdConst = userId
        let templateIdConst = templateId
        let start = dayStart
        let end = dayEnd

        let descriptor = FetchDescriptor<MissedWorkout>(
            predicate: #Predicate { missed in
                missed.userId == userIdConst
                    && missed.templateId == templateIdConst
                    && missed.scheduledDate >= start
                    && missed.scheduledDate < end
            }
        )
        let matches = (try? context.fetch(descriptor)) ?? []
        return matches.contains { $0.action == .pending }
    }

    private func dismissedSheetIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: dismissedSheetsKey) ?? [])
    }
}
