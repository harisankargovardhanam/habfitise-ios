import Foundation

// MARK: - Date / time helpers for Postgres column types

enum SyncDateCoding {
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func encodeDateOnly(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    static func decodeDateOnly(_ string: String) -> Date? {
        if let date = dateOnlyFormatter.date(from: string) {
            return date
        }
        return ISO8601DateFormatter().date(from: string)
    }

    static func encodeTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func decodeTime(_ string: String) -> Date? {
        let trimmed = String(string.prefix(8))
        guard let time = timeFormatter.date(from: trimmed) else { return nil }
        return Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: time),
            minute: Calendar.current.component(.minute, from: time),
            second: Calendar.current.component(.second, from: time),
            of: .now
        )
    }
}

// MARK: - Supabase row DTOs (match existing VAYA Postgres schema)

enum SyncDTOMapper {
    /// `profiles.id` is the Supabase auth user id (not the local SwiftData row id).
    static func userProfile(_ model: UserProfile) -> UserProfileDTO {
        UserProfileDTO(
            id: model.userId,
            displayName: model.displayName,
            age: model.age,
            weightKg: model.weightKg,
            heightCm: model.heightCm,
            goal: model.goal,
            targetWeightKg: model.targetWeightKg,
            goalDeadline: model.goalDeadline,
            timezone: model.timezone,
            fcmToken: model.fcmToken,
            isPro: model.isPro,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    static func workoutSession(_ model: WorkoutSession) -> WorkoutSessionDTO {
        WorkoutSessionDTO(
            id: model.id.uuidString,
            userId: model.userId,
            templateId: model.templateId?.uuidString,
            name: model.name,
            type: model.type.rawValue,
            startedAt: model.startedAt,
            completedAt: model.completedAt,
            durationSeconds: model.durationSeconds,
            totalVolumeKg: model.totalVolumeKg,
            totalCalories: model.totalCalories,
            notes: model.notes,
            mood: model.mood,
            perceivedExertion: model.perceivedExertion,
            remoteId: model.remoteId,
            updatedAt: model.updatedAt
        )
    }

    static func exerciseSet(_ model: ExerciseSet) -> ExerciseSetDTO {
        ExerciseSetDTO(
            id: model.id.uuidString,
            sessionId: model.sessionId.uuidString,
            userId: model.userId,
            exerciseName: model.exerciseName,
            exerciseCategory: model.exerciseCategory,
            setNumber: model.setNumber,
            reps: model.reps,
            weightKg: model.weightKg,
            durationSeconds: model.durationSeconds,
            distanceKm: model.distanceKm,
            isWarmup: model.isWarmup,
            isPersonalRecord: model.isPersonalRecord,
            completedAt: model.completedAt,
            updatedAt: model.updatedAt
        )
    }

    static func habit(_ model: Habit) -> HabitDTO {
        HabitDTO(
            id: model.id.uuidString,
            userId: model.userId,
            name: model.name,
            frequency: model.frequency,
            reminderTime: model.reminderTime,
            colorHex: model.colorHex,
            isActive: model.isActive,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    static func habitCompletion(_ model: HabitCompletion) -> HabitCompletionDTO {
        HabitCompletionDTO(
            id: model.id.uuidString,
            habitId: model.habitId.uuidString,
            userId: model.userId,
            completedDate: model.completedDate,
            updatedAt: model.updatedAt
        )
    }

    static func task(_ model: TaskRecord) -> TaskRecordDTO {
        TaskRecordDTO(
            id: model.id.uuidString,
            userId: model.userId,
            title: model.title,
            dueDate: model.dueDate,
            isComplete: model.isComplete,
            recurrence: model.recurrence,
            linkedHabitId: model.linkedHabitId?.uuidString,
            updatedAt: model.updatedAt
        )
    }

    static func moodCheckin(_ model: MoodCheckin) -> MoodCheckinDTO {
        MoodCheckinDTO(
            id: model.id.uuidString,
            userId: model.userId,
            energyScore: model.energyScore,
            moodScore: model.moodScore,
            note: model.note,
            wearableHrv: model.wearableHrv.map { Int($0.rounded()) },
            wearableSleepHours: model.wearableSleepHours,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    static func waterLog(_ model: WaterLog) -> WaterLogDTO {
        WaterLogDTO(
            id: model.id.uuidString,
            userId: model.userId,
            amountMl: model.amountMl,
            loggedAt: model.loggedAt,
            source: model.source,
            updatedAt: model.updatedAt
        )
    }

    static func waterGoal(_ model: WaterGoal) -> WaterGoalDTO {
        WaterGoalDTO(
            id: model.id.uuidString,
            userId: model.userId,
            dailyGoalMl: model.dailyGoalMl,
            reminderIntervalMinutes: model.reminderIntervalMinutes,
            reminderStartTime: model.reminderStartTime,
            reminderEndTime: model.reminderEndTime,
            isReminderEnabled: model.isReminderEnabled,
            updatedAt: model.updatedAt
        )
    }
}

struct UserProfileDTO: Codable {
    let id: String
    let displayName: String
    let age: Int
    let weightKg: Double
    let heightCm: Double
    let goal: String
    let targetWeightKg: Double
    let goalDeadline: Date
    let timezone: String
    let fcmToken: String?
    let isPro: Bool
    let createdAt: Date
    let updatedAt: Date

    var userId: String { id }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case age
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case goal
        case targetWeightKg = "target_weight_kg"
        case goalDeadline = "goal_deadline"
        case timezone
        case fcmToken = "fcm_token"
        case isPro = "is_pro"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        displayName: String,
        age: Int,
        weightKg: Double,
        heightCm: Double,
        goal: String,
        targetWeightKg: Double,
        goalDeadline: Date,
        timezone: String,
        fcmToken: String?,
        isPro: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.goal = goal
        self.targetWeightKg = targetWeightKg
        self.goalDeadline = goalDeadline
        self.timezone = timezone
        self.fcmToken = fcmToken
        self.isPro = isPro
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 0
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg) ?? 0
        heightCm = try container.decodeIfPresent(Double.self, forKey: .heightCm) ?? 0
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        targetWeightKg = try container.decodeIfPresent(Double.self, forKey: .targetWeightKg) ?? 0
        goalDeadline = try container.decodeIfPresent(Date.self, forKey: .goalDeadline) ?? .now
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? TimeZone.current.identifier
        fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

struct WorkoutSessionDTO: Codable {
    let id: String
    let userId: String
    let templateId: String?
    let name: String
    let type: String
    let startedAt: Date
    let completedAt: Date?
    let durationSeconds: Int
    let totalVolumeKg: Double
    let totalCalories: Int?
    let notes: String
    let mood: Int
    let perceivedExertion: Int
    let remoteId: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case templateId = "plan_id"
        case name
        case type
        case startedAt = "scheduled_date"
        case completedAt = "completed_at"
        case durationSeconds = "duration_seconds"
        case totalVolumeKg = "total_volume_kg"
        case totalCalories = "total_calories"
        case notes
        case mood
        case perceivedExertion = "perceived_exertion"
        case remoteId = "remote_id"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        userId: String,
        templateId: String?,
        name: String,
        type: String,
        startedAt: Date,
        completedAt: Date?,
        durationSeconds: Int,
        totalVolumeKg: Double,
        totalCalories: Int?,
        notes: String,
        mood: Int,
        perceivedExertion: Int,
        remoteId: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.templateId = templateId
        self.name = name
        self.type = type
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.totalVolumeKg = totalVolumeKg
        self.totalCalories = totalCalories
        self.notes = notes
        self.mood = mood
        self.perceivedExertion = perceivedExertion
        self.remoteId = remoteId
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? WorkoutType.weights.rawValue
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
        totalVolumeKg = try container.decodeIfPresent(Double.self, forKey: .totalVolumeKg) ?? 0
        totalCalories = try container.decodeIfPresent(Int.self, forKey: .totalCalories)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        mood = try container.decodeIfPresent(Int.self, forKey: .mood) ?? 3
        perceivedExertion = try container.decodeIfPresent(Int.self, forKey: .perceivedExertion) ?? 5
        remoteId = try container.decodeIfPresent(String.self, forKey: .remoteId)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? startedAt
    }
}

struct ExerciseSetDTO: Codable {
    let id: String
    let sessionId: String
    let userId: String
    let exerciseName: String
    let exerciseCategory: String
    let setNumber: Int
    let reps: Int?
    let weightKg: Double?
    let durationSeconds: Int?
    let distanceKm: Double?
    let isWarmup: Bool
    let isPersonalRecord: Bool
    let completedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case exerciseName = "exercise_name"
        case exerciseCategory = "exercise_category"
        case setNumber = "set_number"
        case reps
        case weightKg = "weight_kg"
        case durationSeconds = "duration_seconds"
        case distanceKm = "distance_km"
        case isWarmup = "is_warmup"
        case isPersonalRecord = "is_personal_record"
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        sessionId: String,
        userId: String,
        exerciseName: String,
        exerciseCategory: String,
        setNumber: Int,
        reps: Int?,
        weightKg: Double?,
        durationSeconds: Int?,
        distanceKm: Double?,
        isWarmup: Bool,
        isPersonalRecord: Bool,
        completedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.exerciseName = exerciseName
        self.exerciseCategory = exerciseCategory
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.distanceKm = distanceKm
        self.isWarmup = isWarmup
        self.isPersonalRecord = isPersonalRecord
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        userId = try container.decode(String.self, forKey: .userId)
        exerciseName = try container.decode(String.self, forKey: .exerciseName)
        exerciseCategory = try container.decodeIfPresent(String.self, forKey: .exerciseCategory) ?? ExerciseCategory.full.rawValue
        setNumber = try container.decode(Int.self, forKey: .setNumber)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
        isPersonalRecord = try container.decodeIfPresent(Bool.self, forKey: .isPersonalRecord) ?? false
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? completedAt
    }
}

struct HabitDTO: Codable {
    let id: String
    let userId: String
    let name: String
    let frequency: String
    let reminderTime: Date?
    let colorHex: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case frequency
        case reminderTime = "reminder_time"
        case colorHex = "color_hex"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        userId: String,
        name: String,
        frequency: String,
        reminderTime: Date?,
        colorHex: String,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.frequency = frequency
        self.reminderTime = reminderTime
        self.colorHex = colorHex
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        frequency = try container.decodeIfPresent(String.self, forKey: .frequency) ?? "daily"
        if let timeString = try container.decodeIfPresent(String.self, forKey: .reminderTime) {
            reminderTime = SyncDateCoding.decodeTime(timeString)
        } else {
            reminderTime = try container.decodeIfPresent(Date.self, forKey: .reminderTime)
        }
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "22C55E"
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encode(frequency, forKey: .frequency)
        if let reminderTime {
            try container.encode(SyncDateCoding.encodeTime(reminderTime), forKey: .reminderTime)
        }
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct HabitCompletionDTO: Codable {
    let id: String
    let habitId: String
    let userId: String
    let completedDate: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case completedDate = "completed_date"
        case updatedAt = "updated_at"
    }

    init(id: String, habitId: String, userId: String, completedDate: Date, updatedAt: Date) {
        self.id = id
        self.habitId = habitId
        self.userId = userId
        self.completedDate = completedDate
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        habitId = try container.decode(String.self, forKey: .habitId)
        userId = try container.decode(String.self, forKey: .userId)
        if let dateString = try? container.decode(String.self, forKey: .completedDate),
           let date = SyncDateCoding.decodeDateOnly(dateString) {
            completedDate = date
        } else {
            completedDate = try container.decode(Date.self, forKey: .completedDate)
        }
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? completedDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(habitId, forKey: .habitId)
        try container.encode(userId, forKey: .userId)
        try container.encode(SyncDateCoding.encodeDateOnly(completedDate), forKey: .completedDate)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct TaskRecordDTO: Codable {
    let id: String
    let userId: String
    let title: String
    let dueDate: Date?
    let isComplete: Bool
    let recurrence: String?
    let linkedHabitId: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case dueDate = "due_date"
        case isComplete = "is_complete"
        case recurrence
        case linkedHabitId = "linked_habit_id"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        userId: String,
        title: String,
        dueDate: Date?,
        isComplete: Bool,
        recurrence: String?,
        linkedHabitId: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.dueDate = dueDate
        self.isComplete = isComplete
        self.recurrence = recurrence
        self.linkedHabitId = linkedHabitId
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dueDate) {
            dueDate = SyncDateCoding.decodeDateOnly(dateString)
        } else {
            dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        }
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        recurrence = try container.decodeIfPresent(String.self, forKey: .recurrence)
        linkedHabitId = try container.decodeIfPresent(String.self, forKey: .linkedHabitId)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(title, forKey: .title)
        if let dueDate {
            try container.encode(SyncDateCoding.encodeDateOnly(dueDate), forKey: .dueDate)
        }
        try container.encode(isComplete, forKey: .isComplete)
        try container.encodeIfPresent(recurrence, forKey: .recurrence)
        try container.encodeIfPresent(linkedHabitId, forKey: .linkedHabitId)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct MoodCheckinDTO: Codable {
    let id: String
    let userId: String
    let energyScore: Int
    let moodScore: Int
    let note: String?
    let wearableHrv: Int?
    let wearableSleepHours: Double?
    let createdAt: Date
    let updatedAt: Date

    var wearableHrvDouble: Double? {
        wearableHrv.map(Double.init)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case energyScore = "energy_score"
        case moodScore = "mood_score"
        case note
        case wearableHrv = "wearable_hrv"
        case wearableSleepHours = "wearable_sleep_hours"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        userId: String,
        energyScore: Int,
        moodScore: Int,
        note: String?,
        wearableHrv: Int?,
        wearableSleepHours: Double?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.energyScore = energyScore
        self.moodScore = moodScore
        self.note = note
        self.wearableHrv = wearableHrv
        self.wearableSleepHours = wearableSleepHours
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        energyScore = try container.decodeIfPresent(Int.self, forKey: .energyScore) ?? 3
        moodScore = try container.decodeIfPresent(Int.self, forKey: .moodScore) ?? 3
        note = try container.decodeIfPresent(String.self, forKey: .note)
        wearableHrv = try container.decodeIfPresent(Int.self, forKey: .wearableHrv)
        wearableSleepHours = try container.decodeIfPresent(Double.self, forKey: .wearableSleepHours)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

struct WaterLogDTO: Codable {
    let id: String
    let userId: String
    let amountMl: Int
    let loggedAt: Date
    let source: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amountMl = "amount_ml"
        case loggedAt = "logged_at"
        case source
        case updatedAt = "updated_at"
    }
}

struct WaterGoalDTO: Codable {
    let id: String
    let userId: String
    let dailyGoalMl: Int
    let reminderIntervalMinutes: Int
    let reminderStartTime: Date
    let reminderEndTime: Date
    let isReminderEnabled: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dailyGoalMl = "daily_goal_ml"
        case reminderIntervalMinutes = "reminder_interval_minutes"
        case reminderStartTime = "reminder_start_time"
        case reminderEndTime = "reminder_end_time"
        case isReminderEnabled = "is_reminder_enabled"
        case updatedAt = "updated_at"
    }
}

enum SyncTable {
    static let userProfiles = "profiles"
    static let workoutSessions = "workout_sessions"
    static let workoutSets = "workout_sets"
    static let habits = "habits"
    static let habitCompletions = "habit_completions"
    static let tasks = "tasks"
    static let moodCheckins = "mood_checkins"
    static let waterLogs = "water_logs"
    static let waterGoals = "water_goals"
}
