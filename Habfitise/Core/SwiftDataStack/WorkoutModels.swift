import Foundation
import SwiftData

// MARK: - Enums

enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case weights = "Weight Training"
    case cardio = "Cardio"
    case bodyweight = "Bodyweight"
    case hiit = "HIIT"
    case flexibility = "Flexibility"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .weights: "dumbbell.fill"
        case .cardio: "figure.run"
        case .bodyweight: "figure.jumprope"
        case .hiit: "bolt.heart.fill"
        case .flexibility: "figure.flexibility"
        }
    }
}

enum ExerciseType: String, Codable, CaseIterable {
    case weighted
    case bodyweight
    case cardio
    case timed
}

enum RepeatSchedule: String, Codable, CaseIterable {
    case nextDay
    case in2Days
    case in3Days
    case nextWeekSameDay
    case custom
}

enum MissedWorkoutAction: String, Codable, CaseIterable {
    case pushed
    case skipped
    case pending
}

enum PRType: String, Codable, CaseIterable {
    case maxWeight
    case maxReps
    case maxVolume
    case fastestPace
    case longestDistance
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case chest, back, legs, shoulders, arms, core, cardio, full
}

// MARK: - WorkoutTemplate

@Model
final class WorkoutTemplate: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var name: String
    var type: WorkoutType
    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.template)
    var exercises: [ExerciseTemplate]
    var estimatedMinutes: Int
    var lastPerformedAt: Date?
    var nextScheduledAt: Date?
    var repeatSchedule: RepeatSchedule?
    var notes: String
    var createdAt: Date
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        name: String,
        type: WorkoutType = .weights,
        exercises: [ExerciseTemplate] = [],
        estimatedMinutes: Int = 45,
        lastPerformedAt: Date? = nil,
        nextScheduledAt: Date? = nil,
        repeatSchedule: RepeatSchedule? = nil,
        notes: String = "",
        createdAt: Date = .now,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.type = type
        self.exercises = exercises
        self.estimatedMinutes = estimatedMinutes
        self.lastPerformedAt = lastPerformedAt
        self.nextScheduledAt = nextScheduledAt
        self.repeatSchedule = repeatSchedule
        self.notes = notes
        self.createdAt = createdAt
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - ExerciseTemplate

@Model
final class ExerciseTemplate {
    @Attribute(.unique) var id: UUID
    var templateId: UUID
    var name: String
    var category: ExerciseCategory
    var type: ExerciseType
    var defaultSets: Int
    var defaultReps: Int
    var defaultWeightKg: Double
    var defaultDurationSeconds: Int
    var defaultDistanceKm: Double
    var order: Int
    var notes: String
    var supersetGroupId: UUID?
    var template: WorkoutTemplate?

    init(
        id: UUID = UUID(),
        templateId: UUID,
        name: String,
        category: ExerciseCategory = .full,
        type: ExerciseType = .weighted,
        defaultSets: Int = 3,
        defaultReps: Int = 10,
        defaultWeightKg: Double = 0,
        defaultDurationSeconds: Int = 0,
        defaultDistanceKm: Double = 0,
        order: Int = 0,
        notes: String = "",
        supersetGroupId: UUID? = nil,
        template: WorkoutTemplate? = nil
    ) {
        self.id = id
        self.templateId = templateId
        self.name = name
        self.category = category
        self.type = type
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeightKg = defaultWeightKg
        self.defaultDurationSeconds = defaultDurationSeconds
        self.defaultDistanceKm = defaultDistanceKm
        self.order = order
        self.notes = notes
        self.supersetGroupId = supersetGroupId
        self.template = template
    }
}

// MARK: - WorkoutSession

@Model
final class WorkoutSession: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var templateId: UUID?
    var name: String
    var type: WorkoutType
    var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int
    var totalVolumeKg: Double
    var totalCalories: Int?
    var notes: String
    var mood: Int
    var perceivedExertion: Int
    var synced: Bool
    var remoteId: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        templateId: UUID? = nil,
        name: String,
        type: WorkoutType = .weights,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        durationSeconds: Int = 0,
        totalVolumeKg: Double = 0,
        totalCalories: Int? = nil,
        notes: String = "",
        mood: Int = 3,
        perceivedExertion: Int = 5,
        synced: Bool = false,
        remoteId: String? = nil,
        updatedAt: Date = .now
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
        self.synced = synced
        self.remoteId = remoteId
        self.updatedAt = updatedAt
    }
}

// MARK: - ExerciseSet

@Model
final class ExerciseSet: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var userId: String
    var exerciseName: String
    var exerciseCategory: String
    var setNumber: Int
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Int?
    var distanceKm: Double?
    var isWarmup: Bool
    var isPersonalRecord: Bool
    var completedAt: Date
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        userId: String,
        exerciseName: String,
        exerciseCategory: String = ExerciseCategory.full.rawValue,
        setNumber: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSeconds: Int? = nil,
        distanceKm: Double? = nil,
        isWarmup: Bool = false,
        isPersonalRecord: Bool = false,
        completedAt: Date = .now,
        synced: Bool = false,
        updatedAt: Date = .now
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
        self.synced = synced
        self.updatedAt = updatedAt
    }

    var volumeKg: Double {
        guard let reps, let weightKg else { return 0 }
        return weightKg * Double(reps)
    }
}

// MARK: - MissedWorkout

@Model
final class MissedWorkout: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var templateId: UUID
    var scheduledDate: Date
    var detectedAt: Date
    var action: MissedWorkoutAction
    var pushedToDate: Date?
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        templateId: UUID,
        scheduledDate: Date,
        detectedAt: Date = .now,
        action: MissedWorkoutAction = .pending,
        pushedToDate: Date? = nil,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.templateId = templateId
        self.scheduledDate = scheduledDate
        self.detectedAt = detectedAt
        self.action = action
        self.pushedToDate = pushedToDate
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - PersonalRecord

@Model
final class PersonalRecord: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var exerciseName: String
    var recordType: PRType
    var value: Double
    var unit: String
    var achievedAt: Date
    var sessionId: UUID
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        exerciseName: String,
        recordType: PRType,
        value: Double,
        unit: String,
        achievedAt: Date = .now,
        sessionId: UUID,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.exerciseName = exerciseName
        self.recordType = recordType
        self.value = value
        self.unit = unit
        self.achievedAt = achievedAt
        self.sessionId = sessionId
        self.synced = synced
        self.updatedAt = updatedAt
    }
}
