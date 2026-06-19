import Foundation

// MARK: - Supabase row DTOs (snake_case columns, UUID strings, ISO8601 dates)

enum SyncDTOMapper {
    static func userProfile(_ model: UserProfile) -> UserProfileDTO {
        UserProfileDTO(
            id: model.id.uuidString,
            userId: model.userId,
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
            wearableHrv: model.wearableHrv,
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

struct UserProfileDTO: Encodable {
    let id: String
    let userId: String
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

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
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
}

struct WorkoutSessionDTO: Encodable {
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
        case templateId = "template_id"
        case name
        case type
        case startedAt = "started_at"
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
}

struct ExerciseSetDTO: Encodable {
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
}

struct HabitDTO: Encodable {
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
}

struct HabitCompletionDTO: Encodable {
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
}

struct TaskRecordDTO: Encodable {
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
}

struct MoodCheckinDTO: Encodable {
    let id: String
    let userId: String
    let energyScore: Int
    let moodScore: Int
    let note: String?
    let wearableHrv: Double?
    let wearableSleepHours: Double?
    let createdAt: Date
    let updatedAt: Date

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
}

struct WaterLogDTO: Encodable {
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

struct WaterGoalDTO: Encodable {
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
    static let userProfiles = "user_profiles"
    static let workoutSessions = "workout_sessions"
    static let workoutSets = "workout_sets"
    static let habits = "habits"
    static let habitCompletions = "habit_completions"
    static let tasks = "tasks"
    static let moodCheckins = "mood_checkins"
    static let waterLogs = "water_logs"
    static let waterGoals = "water_goals"
}
