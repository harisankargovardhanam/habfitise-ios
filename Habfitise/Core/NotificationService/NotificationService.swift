import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self

        let start = UNNotificationAction(
            identifier: AppConstants.Notifications.actionStart,
            title: "Start",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: AppConstants.Notifications.actionSnooze,
            title: "Snooze 1hr",
            options: []
        )
        let workoutCategory = UNNotificationCategory(
            identifier: AppConstants.Notifications.workoutReminderCategory,
            actions: [start, snooze],
            intentIdentifiers: [],
            options: []
        )

        let pushTomorrow = UNNotificationAction(
            identifier: AppConstants.Notifications.actionPushTomorrow,
            title: "Push to tomorrow",
            options: []
        )
        let skip = UNNotificationAction(
            identifier: AppConstants.Notifications.actionSkip,
            title: "Skip",
            options: []
        )
        let missedCategory = UNNotificationCategory(
            identifier: AppConstants.Notifications.missedWorkoutCategory,
            actions: [pushTomorrow, skip],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([workoutCategory, missedCategory])
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    /// Remote push via FCM deferred — see Config/DEFERRED.md
    func registerForRemoteNotifications() {}

    func scheduleWorkoutReminder(template: WorkoutTemplate) async {
        guard let scheduledAt = template.nextScheduledAt else {
            await cancelWorkoutReminder(templateId: template.id)
            return
        }
        guard let fireDate = reminderDate(for: scheduledAt), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to train 💪"
        content.body = "Your \(template.name) is ready. Let's go."
        content.categoryIdentifier = AppConstants.Notifications.workoutReminderCategory
        content.sound = .default
        content.userInfo = [
            AppConstants.Notifications.userInfoTemplateId: template.id.uuidString
        ]

        await schedule(
            id: workoutReminderId(template.id),
            content: content,
            at: fireDate
        )
    }

    func scheduleMissedWorkoutReminder(missed: MissedWorkout, template: WorkoutTemplate) async {
        var fireDate = missed.scheduledDate.addingTimeInterval(8 * 60 * 60)
        if fireDate <= .now {
            fireDate = Date().addingTimeInterval(60)
        }

        let content = UNMutableNotificationContent()
        content.title = "How's your day going?"
        content.body = "Your \(template.name) is still here when you're ready."
        content.categoryIdentifier = AppConstants.Notifications.missedWorkoutCategory
        content.sound = .default
        content.userInfo = [
            AppConstants.Notifications.userInfoTemplateId: template.id.uuidString,
            AppConstants.Notifications.userInfoMissedId: missed.id.uuidString
        ]

        await schedule(
            id: missedReminderId(missed.id),
            content: content,
            at: fireDate
        )
    }

    func cancelWorkoutReminder(templateId: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [workoutReminderId(templateId)]
        )
    }

    func cancelMissedWorkoutReminder(missedId: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [missedReminderId(missedId)]
        )
    }

    func snoozeWorkoutReminder(templateId: UUID, templateName: String) async {
        let fireDate = Date().addingTimeInterval(60 * 60)
        let content = UNMutableNotificationContent()
        content.title = "Time to train 💪"
        content.body = "Your \(templateName) is ready. Let's go."
        content.categoryIdentifier = AppConstants.Notifications.workoutReminderCategory
        content.sound = .default
        content.userInfo = [
            AppConstants.Notifications.userInfoTemplateId: templateId.uuidString
        ]
        await schedule(id: workoutReminderId(templateId), content: content, at: fireDate)
    }

    // MARK: - Private

    private func schedule(id: String, content: UNNotificationContent, at date: Date) async {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func workoutReminderId(_ templateId: UUID) -> String {
        "workout-reminder-\(templateId.uuidString)"
    }

    private func missedReminderId(_ missedId: UUID) -> String {
        "missed-workout-\(missedId.uuidString)"
    }

    private func reminderDate(for scheduledAt: Date) -> Date? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: scheduledAt)
        let preferredHour = Self.preferredWorkoutHour()
        guard let workoutTime = calendar.date(bySettingHour: preferredHour, minute: 0, second: 0, of: day) else {
            return nil
        }
        return calendar.date(byAdding: .hour, value: -1, to: workoutTime)
    }

    static func preferredWorkoutHour() -> Int {
        let raw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.preferredWorkoutTime)
            ?? PreferredTrainingTime.morning.rawValue
        switch PreferredTrainingTime(rawValue: raw) ?? .morning {
        case .morning: return 7
        case .afternoon: return 12
        case .evening: return 18
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handleNotificationResponse(response)
    }

    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard
            let templateIdString = userInfo[AppConstants.Notifications.userInfoTemplateId] as? String,
            let templateId = UUID(uuidString: templateIdString)
        else { return }

        let context = SwiftDataStack.shared.mainContext
        let templateIdConst = templateId
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.id == templateIdConst }
        )
        guard let template = try? context.fetch(descriptor).first else { return }

        switch response.actionIdentifier {
        case AppConstants.Notifications.actionStart:
            await MainActor.run {
                // AppState wired via notification callback in HabfitiseApp bootstrap if needed
                WorkoutNotificationBridge.shared.requestStart(template: template)
            }

        case AppConstants.Notifications.actionSnooze:
            await snoozeWorkoutReminder(templateId: template.id, templateName: template.name)

        case AppConstants.Notifications.actionPushTomorrow:
            if let missedIdString = userInfo[AppConstants.Notifications.userInfoMissedId] as? String,
               let missedId = UUID(uuidString: missedIdString) {
                let missedIdConst = missedId
                let missedDescriptor = FetchDescriptor<MissedWorkout>(
                    predicate: #Predicate { $0.id == missedIdConst }
                )
                if let missed = try? context.fetch(missedDescriptor).first {
                    MissedWorkoutService.shared.resolve(
                        missed: missed,
                        template: template,
                        response: .pushTomorrow,
                        context: context
                    )
                    await cancelMissedWorkoutReminder(missedId: missed.id)
                }
            }

        case AppConstants.Notifications.actionSkip:
            if let missedIdString = userInfo[AppConstants.Notifications.userInfoMissedId] as? String,
               let missedId = UUID(uuidString: missedIdString) {
                let missedIdConst = missedId
                let missedDescriptor = FetchDescriptor<MissedWorkout>(
                    predicate: #Predicate { $0.id == missedIdConst }
                )
                if let missed = try? context.fetch(missedDescriptor).first {
                    MissedWorkoutService.shared.resolve(
                        missed: missed,
                        template: template,
                        response: .skip,
                        context: context
                    )
                    await cancelMissedWorkoutReminder(missedId: missed.id)
                }
            }

        default:
            break
        }
    }
}

@Observable
@MainActor
final class WorkoutNotificationBridge {
    static let shared = WorkoutNotificationBridge()
    var pendingBuilder: PendingWorkoutBuilder?

    private init() {}

    func requestStart(template: WorkoutTemplate) {
        pendingBuilder = PendingWorkoutBuilder(workoutType: template.type, templateId: template.id)
    }

    func consumePendingBuilder() -> PendingWorkoutBuilder? {
        defer { pendingBuilder = nil }
        return pendingBuilder
    }
}
