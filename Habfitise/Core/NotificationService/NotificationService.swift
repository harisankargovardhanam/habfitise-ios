import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: AppConstants.UserDefaultsKeys.notificationsEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.notificationsEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppConstants.UserDefaultsKeys.notificationsEnabled)
        }
    }

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

        let habitCategory = UNNotificationCategory(
            identifier: AppConstants.Notifications.habitReminderCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let waterCategory = UNNotificationCategory(
            identifier: AppConstants.Notifications.waterReminderCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories(
            [workoutCategory, missedCategory, habitCategory, waterCategory]
        )
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func ensureAuthorization() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await requestAuthorization()) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func rescheduleAllWorkoutReminders(userId: String, context: ModelContext) async {
        guard isEnabled else { return }
        guard await ensureAuthorization() else { return }

        let userIdConst = userId
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.userId == userIdConst && $0.nextScheduledAt != nil }
        )
        let templates = (try? context.fetch(descriptor)) ?? []
        for template in templates {
            await scheduleWorkoutReminder(template: template)
        }
    }

    func rescheduleAllHabitReminders(userId: String, context: ModelContext) async {
        guard isEnabled else { return }
        guard await ensureAuthorization() else { return }

        let userIdConst = userId
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.userId == userIdConst && $0.isActive }
        )
        let habits = (try? context.fetch(descriptor)) ?? []
        for habit in habits where habit.reminderTime != nil {
            await scheduleHabitReminder(habit: habit, context: context)
        }
    }

    func rescheduleAllReminders(userId: String, context: ModelContext) async {
        await rescheduleAllWorkoutReminders(userId: userId, context: context)
        await rescheduleAllHabitReminders(userId: userId, context: context)
        await rescheduleWaterReminders(userId: userId, context: context)
    }

    // MARK: - Water reminders

    func rescheduleWaterReminders(userId: String, context: ModelContext) async {
        guard SwiftDataStack.shared.userProfileExists(userId: userId, context: context) else {
            await cancelWaterReminders(userId: userId)
            return
        }
        guard isEnabled else {
            await cancelWaterReminders(userId: userId)
            return
        }
        guard await ensureAuthorization() else { return }

        let settings = resolveWaterReminderSettings(userId: userId, context: context)
        guard settings.isReminderEnabled else {
            await cancelWaterReminders(userId: userId)
            return
        }

        let todayMl = waterLoggedToday(userId: userId, context: context)
        let remainingMl = max(0, settings.dailyGoalMl - todayMl)

        await cancelWaterReminders(userId: userId)

        guard remainingMl > 0 else { return }

        let fireDates = upcomingWaterReminderDates(settings: settings)
        guard !fireDates.isEmpty else { return }

        let calendar = Calendar.current
        for (index, fireDate) in fireDates.enumerated() {
            let isToday = calendar.isDateInToday(fireDate)
            let pendingMl = isToday ? remainingMl : settings.dailyGoalMl
            let content = waterReminderContent(
                pendingMl: pendingMl,
                goalMl: settings.dailyGoalMl,
                userId: userId
            )
            let dayKey = Self.dayKey(for: fireDate, calendar: calendar)
            await schedule(
                id: waterReminderId(userId: userId, dayKey: dayKey, slot: index),
                content: content,
                at: fireDate
            )
        }
    }

    func cancelWaterReminders(userId: String) async {
        let prefix = waterReminderPrefix(userId: userId)
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func scheduleHabitReminder(habit: Habit, context: ModelContext) async {
        guard isEnabled else { return }
        guard await ensureAuthorization() else { return }
        guard habit.isActive, let reminderTime = habit.reminderTime else {
            await cancelHabitReminder(habitId: habit.id)
            return
        }

        await cancelHabitReminder(habitId: habit.id)

        guard let fireDate = nextHabitFireDate(
            habit: habit,
            reminderTime: reminderTime,
            context: context
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Habit reminder"
        content.body = "Time for \(habit.name)."
        content.categoryIdentifier = AppConstants.Notifications.habitReminderCategory
        content.sound = .default
        content.userInfo = [
            AppConstants.Notifications.userInfoHabitId: habit.id.uuidString
        ]

        await schedule(
            id: habitReminderId(habit.id),
            content: content,
            at: fireDate
        )
    }

    func cancelHabitReminder(habitId: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [habitReminderId(habitId)]
        )
    }

    func cancelAllPendingReminders() {
        resetAllReminders()
    }

    /// Removes every pending and delivered local notification.
    func resetAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Drops water reminders for deleted accounts or prior local sessions.
    func pruneStaleWaterReminders(activeUserId: String?, context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let staleIds = pending.compactMap { request -> String? in
            guard request.identifier.hasPrefix(Self.waterReminderIdentifierPrefix) else { return nil }
            guard
                let userId = request.content.userInfo[AppConstants.Notifications.userInfoUserId] as? String
            else {
                return request.identifier
            }
            let isActiveUser = userId == activeUserId
            let profileExists = SwiftDataStack.shared.userProfileExists(userId: userId, context: context)
            return (isActiveUser && profileExists) ? nil : request.identifier
        }
        guard !staleIds.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: staleIds)
    }

    /// Remote push via FCM deferred — see Config/DEFERRED.md
    func registerForRemoteNotifications() {}

    func scheduleWorkoutReminder(template: WorkoutTemplate) async {
        guard isEnabled else { return }
        guard await ensureAuthorization() else { return }

        guard let scheduledAt = template.nextScheduledAt else {
            await cancelWorkoutReminder(templateId: template.id)
            return
        }
        guard let fireDate = reminderDate(for: scheduledAt) else {
            await cancelWorkoutReminder(templateId: template.id)
            return
        }

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
        guard isEnabled else { return }
        guard await ensureAuthorization() else { return }

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
        guard date > .now else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            #if DEBUG
            print("NotificationService: failed to schedule \(id) — \(error.localizedDescription)")
            #endif
        }
    }

    private func workoutReminderId(_ templateId: UUID) -> String {
        "workout-reminder-\(templateId.uuidString)"
    }

    private func missedReminderId(_ missedId: UUID) -> String {
        "missed-workout-\(missedId.uuidString)"
    }

    private func habitReminderId(_ habitId: UUID) -> String {
        "habit-reminder-\(habitId.uuidString)"
    }

    private func waterReminderPrefix(userId: String) -> String {
        "water-reminder-\(userId)-"
    }

    private static let waterReminderIdentifierPrefix = "water-reminder-"

    private func waterReminderId(userId: String, dayKey: String, slot: Int) -> String {
        "\(waterReminderPrefix(userId: userId))\(dayKey)-\(slot)"
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d%02d%02d", year, month, day)
    }

    private struct WaterReminderSettings {
        let dailyGoalMl: Int
        let reminderIntervalMinutes: Int
        let reminderStartTime: Date
        let reminderEndTime: Date
        let isReminderEnabled: Bool
    }

    private func resolveWaterReminderSettings(userId: String, context: ModelContext) -> WaterReminderSettings {
        let userIdConst = userId
        let descriptor = FetchDescriptor<WaterGoal>(
            predicate: #Predicate { $0.userId == userIdConst }
        )
        if let goal = try? context.fetch(descriptor).first {
            return WaterReminderSettings(
                dailyGoalMl: goal.dailyGoalMl,
                reminderIntervalMinutes: max(
                    goal.reminderIntervalMinutes,
                    AppConstants.Water.minimumReminderIntervalMinutes
                ),
                reminderStartTime: goal.reminderStartTime,
                reminderEndTime: goal.reminderEndTime,
                isReminderEnabled: goal.isReminderEnabled
            )
        }

        let storedGoal = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.dailyWaterGoalML)
        let dailyGoal = storedGoal > 0 ? storedGoal : AppConstants.Water.defaultDailyGoalML
        let calendar = Calendar.current
        return WaterReminderSettings(
            dailyGoalMl: dailyGoal,
            reminderIntervalMinutes: AppConstants.Water.defaultReminderIntervalMinutes,
            reminderStartTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now,
            reminderEndTime: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now,
            isReminderEnabled: false
        )
    }

    private func waterLoggedToday(userId: String, context: ModelContext) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? .now
        let userIdConst = userId
        let descriptor = FetchDescriptor<WaterLog>(
            predicate: #Predicate { log in
                log.userId == userIdConst
                    && log.loggedAt >= start
                    && log.loggedAt < end
            }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.reduce(0) { $0 + $1.amountMl }
    }

    private func upcomingWaterReminderDates(
        settings: WaterReminderSettings,
        from: Date = .now,
        horizonDays: Int = 1,
        maxCount: Int = AppConstants.Water.maxPendingReminders
    ) -> [Date] {
        let calendar = Calendar.current
        let interval = max(
            settings.reminderIntervalMinutes,
            AppConstants.Water.minimumReminderIntervalMinutes
        )
        let startHour = calendar.component(.hour, from: settings.reminderStartTime)
        let startMinute = calendar.component(.minute, from: settings.reminderStartTime)
        let endHour = calendar.component(.hour, from: settings.reminderEndTime)
        let endMinute = calendar.component(.minute, from: settings.reminderEndTime)

        var dates: [Date] = []
        let startDay = calendar.startOfDay(for: from)

        for dayOffset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startDay) else { continue }
            guard let windowStart = calendar.date(
                bySettingHour: startHour,
                minute: startMinute,
                second: 0,
                of: day
            ), let windowEnd = calendar.date(
                bySettingHour: endHour,
                minute: endMinute,
                second: 0,
                of: day
            ), windowEnd > windowStart else { continue }

            var cursor = dayOffset == 0 ? max(windowStart, from.addingTimeInterval(60)) : windowStart
            while cursor <= windowEnd, dates.count < maxCount {
                dates.append(cursor)
                guard let next = calendar.date(byAdding: .minute, value: interval, to: cursor) else { break }
                cursor = next
            }
        }

        return dates
    }

    private func waterReminderContent(pendingMl: Int, goalMl: Int, userId: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to hydrate"
        content.body = waterReminderBody(pendingMl: pendingMl, goalMl: goalMl)
        content.categoryIdentifier = AppConstants.Notifications.waterReminderCategory
        content.sound = .default
        content.userInfo = [
            AppConstants.Notifications.userInfoUserId: userId,
            AppConstants.Notifications.userInfoNotificationType: NotificationTypes.waterReminder
        ]
        return content
    }

    private func waterReminderBody(pendingMl: Int, goalMl: Int) -> String {
        let formattedPending = Self.formattedWaterML(pendingMl)
        let formattedGoal = Self.formattedWaterML(goalMl)

        if pendingMl <= AppConstants.Water.cupSizeML {
            return "Almost there — only \(formattedPending) ml left to hit your \(formattedGoal) ml goal."
        }
        return "\(formattedPending) ml still to drink today (goal: \(formattedGoal) ml). Log a glass in VAYA."
    }

    private static func formattedWaterML(_ ml: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: ml)) ?? "\(ml)"
    }

    private func nextHabitFireDate(
        habit: Habit,
        reminderTime: Date,
        context: ModelContext,
        after: Date = .now
    ) -> Date? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        let startDay = calendar.startOfDay(for: after)

        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            guard isHabitDue(habit, on: day, calendar: calendar) else { continue }
            guard let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
                continue
            }
            guard fireDate > after else { continue }
            if calendar.isDate(day, inSameDayAs: after),
               isHabitCompletedToday(habitId: habit.id, context: context, calendar: calendar) {
                continue
            }
            return fireDate
        }
        return nil
    }

    private func isHabitDue(_ habit: Habit, on day: Date, calendar: Calendar) -> Bool {
        let frequency = habit.frequency.lowercased()
        if frequency == "daily" || frequency.isEmpty {
            return true
        }

        let weekdayKey = Self.weekdayKey(for: day, calendar: calendar)
        let scheduledDays = frequency
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return scheduledDays.contains(weekdayKey)
    }

    private func isHabitCompletedToday(
        habitId: UUID,
        context: ModelContext,
        calendar: Calendar
    ) -> Bool {
        let today = calendar.startOfDay(for: .now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return false }

        let habitIdConst = habitId
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate { completion in
                completion.habitId == habitIdConst
                    && completion.completedDate >= today
                    && completion.completedDate < tomorrow
            }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private static func weekdayKey(for date: Date, calendar: Calendar) -> String {
        let keys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        let index = (calendar.component(.weekday, from: date) + 5) % 7
        return keys[index]
    }

    private func reminderDate(for scheduledAt: Date) -> Date? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: scheduledAt)
        let preferredHour = Self.preferredWorkoutHour()
        guard let workoutTime = calendar.date(bySettingHour: preferredHour, minute: 0, second: 0, of: day) else {
            return nil
        }

        if let reminder = calendar.date(byAdding: .hour, value: -1, to: workoutTime), reminder > .now {
            return reminder
        }

        // Reminder window already passed but the workout day is still ahead — nudge soon.
        if workoutTime > .now {
            return Date().addingTimeInterval(60)
        }

        // Workout day already passed — schedule for the next calendar day at the usual reminder time.
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
              let nextWorkoutTime = calendar.date(bySettingHour: preferredHour, minute: 0, second: 0, of: nextDay),
              let nextReminder = calendar.date(byAdding: .hour, value: -1, to: nextWorkoutTime) else {
            return nil
        }
        return nextReminder > .now ? nextReminder : Date().addingTimeInterval(60)
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
        await rescheduleDeliveredHabitReminderIfNeeded(notification)
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await rescheduleDeliveredHabitReminderIfNeeded(response.notification)
        await rescheduleDeliveredWaterRemindersIfNeeded(response.notification)
        await handleNotificationResponse(response)
    }

    private func rescheduleDeliveredHabitReminderIfNeeded(_ notification: UNNotification) async {
        let userInfo = notification.request.content.userInfo
        guard
            let habitIdString = userInfo[AppConstants.Notifications.userInfoHabitId] as? String,
            let habitId = UUID(uuidString: habitIdString)
        else { return }

        let context = SwiftDataStack.shared.mainContext
        let habitIdConst = habitId
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.id == habitIdConst }
        )
        guard let habit = try? context.fetch(descriptor).first else { return }
        await scheduleHabitReminder(habit: habit, context: context)
    }

    private func rescheduleDeliveredWaterRemindersIfNeeded(_ notification: UNNotification) async {
        let userInfo = notification.request.content.userInfo
        guard
            userInfo[AppConstants.Notifications.userInfoNotificationType] as? String == NotificationTypes.waterReminder,
            let userId = userInfo[AppConstants.Notifications.userInfoUserId] as? String
        else { return }

        let context = SwiftDataStack.shared.mainContext
        guard SwiftDataStack.shared.userProfileExists(userId: userId, context: context) else {
            await cancelWaterReminders(userId: userId)
            return
        }
        await rescheduleWaterReminders(userId: userId, context: context)
    }

    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if userInfo[AppConstants.Notifications.userInfoHabitId] != nil {
            return
        }
        if userInfo[AppConstants.Notifications.userInfoNotificationType] as? String == NotificationTypes.waterReminder {
            return
        }

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
