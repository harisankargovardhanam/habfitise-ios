import Foundation

// MARK: - Builder enums

enum CardioTrackingMode: String, CaseIterable, Identifiable {
    case distance
    case duration
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .distance: "Distance"
        case .duration: "Duration"
        case .both: "Both"
        }
    }
}

enum CardioIntensity: String, CaseIterable, Identifiable {
    case easy
    case moderate
    case intense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .moderate: "Moderate"
        case .intense: "Intense"
        }
    }

    /// Rough multiplier for calorie estimates.
    var calorieMultiplier: Double {
        switch self {
        case .easy: 0.85
        case .moderate: 1.0
        case .intense: 1.2
        }
    }
}

enum WeightDisplayUnit: String, CaseIterable, Identifiable {
    case kg
    case lbs

    var id: String { rawValue }

    var title: String { rawValue }
}

// MARK: - Builder draft models

struct BuilderDraftExercise: Identifiable, Equatable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var type: ExerciseType
    var defaultSets: Int
    var defaultReps: Int
    var defaultWeightKg: Double
    var defaultDurationSeconds: Int
    var defaultDistanceKm: Double
    var restSeconds: Int
    var notes: String
    var order: Int
    var warmupSetsEnabled: Bool
    var weightUnit: WeightDisplayUnit
    var cardioMode: CardioTrackingMode
    var cardioIntensity: CardioIntensity
    var equipmentSetting: String
    var supersetGroupId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory = .full,
        type: ExerciseType = .weighted,
        defaultSets: Int = 3,
        defaultReps: Int = 10,
        defaultWeightKg: Double = 0,
        defaultDurationSeconds: Int = 0,
        defaultDistanceKm: Double = 0,
        restSeconds: Int = 90,
        notes: String = "",
        order: Int = 0,
        warmupSetsEnabled: Bool = false,
        weightUnit: WeightDisplayUnit = .kg,
        cardioMode: CardioTrackingMode = .both,
        cardioIntensity: CardioIntensity = .moderate,
        equipmentSetting: String = "",
        supersetGroupId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.type = type
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeightKg = defaultWeightKg
        self.defaultDurationSeconds = defaultDurationSeconds
        self.defaultDistanceKm = defaultDistanceKm
        self.restSeconds = restSeconds
        self.notes = notes
        self.order = order
        self.warmupSetsEnabled = warmupSetsEnabled
        self.weightUnit = weightUnit
        self.cardioMode = cardioMode
        self.cardioIntensity = cardioIntensity
        self.equipmentSetting = equipmentSetting
        self.supersetGroupId = supersetGroupId
    }

    init(from template: ExerciseTemplate) {
        self.id = template.id
        self.name = template.name
        self.category = template.category
        self.type = template.type
        self.defaultSets = template.defaultSets
        self.defaultReps = template.defaultReps
        self.defaultWeightKg = template.defaultWeightKg
        self.defaultDurationSeconds = template.defaultDurationSeconds
        self.defaultDistanceKm = template.defaultDistanceKm
        self.restSeconds = 90
        self.notes = template.notes
        self.order = template.order
        self.warmupSetsEnabled = false
        self.weightUnit = .kg
        self.cardioMode = template.defaultDurationSeconds > 0 && template.defaultDistanceKm > 0
            ? .both
            : (template.defaultDurationSeconds > 0 ? .duration : .distance)
        self.cardioIntensity = .moderate
        self.equipmentSetting = ""
        self.supersetGroupId = template.supersetGroupId
    }

    var isStrengthLike: Bool {
        type == .weighted || type == .bodyweight
    }

    var showsCardioEquipment: Bool {
        guard type == .cardio else { return false }
        let lower = name.lowercased()
        return lower.contains("treadmill") || lower.contains("rowing") || lower.contains("cycling")
    }

    var equipmentFieldLabel: String {
        let lower = name.lowercased()
        if lower.contains("treadmill") { return "Incline" }
        if lower.contains("rowing") { return "Resistance" }
        if lower.contains("cycling") { return "Level" }
        return "Equipment"
    }

    var setsPreview: String {
        switch type {
        case .cardio, .timed:
            switch cardioMode {
            case .both:
                if defaultDurationSeconds > 0, defaultDistanceKm > 0 {
                    return "\(formatDuration(defaultDurationSeconds)) · \(String(format: "%.1f", defaultDistanceKm)) km"
                }
                fallthrough
            case .duration:
                if defaultDurationSeconds > 0 {
                    return formatDuration(defaultDurationSeconds)
                }
            case .distance:
                if defaultDistanceKm > 0 {
                    return "\(String(format: "%.1f", defaultDistanceKm)) km"
                }
            }
            return type == .timed ? "Timed set" : "Cardio set"
        case .bodyweight:
            if warmupSetsEnabled {
                return "Warmup + \(defaultSets) × \(defaultReps)"
            }
            return "\(defaultSets) × \(defaultReps)"
        case .weighted:
            if defaultWeightKg > 0 {
                let prefix = warmupSetsEnabled ? "Warmup + " : ""
                return "\(prefix)\(defaultSets) × \(defaultReps) @ \(Int(defaultWeightKg)) kg"
            }
            return warmupSetsEnabled ? "Warmup + \(defaultSets) sets" : "\(defaultSets) sets"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct BuilderSetState: Identifiable, Equatable {
    let id: UUID
    var setNumber: Int
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Int?
    var distanceKm: Double?
    var isWarmup: Bool
    var isCompleted: Bool
    var isPersonalRecord: Bool
    var previousSummary: String

    init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSeconds: Int? = nil,
        distanceKm: Double? = nil,
        isWarmup: Bool = false,
        isCompleted: Bool = false,
        isPersonalRecord: Bool = false,
        previousSummary: String = "—"
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.distanceKm = distanceKm
        self.isWarmup = isWarmup
        self.isCompleted = isCompleted
        self.isPersonalRecord = isPersonalRecord
        self.previousSummary = previousSummary
    }
}

struct CatalogExercise: Identifiable, Equatable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let type: ExerciseType
    let emoji: String

    var idKey: String { id }
}

struct CardioOption: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
}

// MARK: - Catalog

enum WorkoutExerciseCatalog {
    static let strength: [CatalogExercise] = [
        CatalogExercise(id: "bench", name: "Bench Press", category: .chest, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "incline-db", name: "Incline DB Press", category: .chest, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "cable-fly", name: "Cable Fly", category: .chest, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "pull-up", name: "Pull-ups", category: .back, type: .bodyweight, emoji: "💪"),
        CatalogExercise(id: "barbell-row", name: "Barbell Row", category: .back, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "lat-pulldown", name: "Lat Pulldown", category: .back, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "squat", name: "Barbell Squat", category: .legs, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "rdl", name: "Romanian Deadlift", category: .legs, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "leg-press", name: "Leg Press", category: .legs, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "ohp", name: "Overhead Press", category: .shoulders, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "lat-raise", name: "Lateral Raise", category: .shoulders, type: .weighted, emoji: "🏋️"),
        CatalogExercise(id: "curl", name: "Bicep Curl", category: .arms, type: .weighted, emoji: "💪"),
        CatalogExercise(id: "tricep-push", name: "Tricep Pushdown", category: .arms, type: .weighted, emoji: "💪"),
        CatalogExercise(id: "push-up", name: "Push-ups", category: .chest, type: .bodyweight, emoji: "🤸"),
        CatalogExercise(id: "plank", name: "Plank", category: .core, type: .timed, emoji: "🧘"),
        CatalogExercise(id: "crunch", name: "Crunches", category: .core, type: .bodyweight, emoji: "🤸")
    ]

    static let cardio: [CardioOption] = [
        CardioOption(id: "treadmill", name: "Treadmill", emoji: "🏃"),
        CardioOption(id: "cycling", name: "Cycling", emoji: "🚴"),
        CardioOption(id: "swimming", name: "Swimming", emoji: "🏊"),
        CardioOption(id: "rowing", name: "Rowing Machine", emoji: "🚣"),
        CardioOption(id: "stair", name: "Stair Climber", emoji: "🧗"),
        CardioOption(id: "elliptical", name: "Elliptical", emoji: "🎿"),
        CardioOption(id: "outdoor-run", name: "Outdoor Run", emoji: "🏃"),
        CardioOption(id: "outdoor-cycle", name: "Outdoor Cycling", emoji: "🚴"),
        CardioOption(id: "walking", name: "Walking", emoji: "🚶"),
        CardioOption(id: "open-water", name: "Open Water Swim", emoji: "🏊"),
        CardioOption(id: "boxing", name: "Boxing", emoji: "🥊"),
        CardioOption(id: "dance", name: "Dance/Zumba", emoji: "💃"),
        CardioOption(id: "skiing", name: "Skiing", emoji: "⛷"),
        CardioOption(id: "badminton", name: "Badminton", emoji: "🏸"),
        CardioOption(id: "sport", name: "Sport (custom)", emoji: "⚽")
    ]

    static func filtered(category: ExerciseCategory?, query: String, workoutType: WorkoutType) -> [CatalogExercise] {
        var items = strength
        if workoutType == .bodyweight {
            items = items.filter { $0.type == .bodyweight || $0.type == .timed }
        }
        if let category, category != .full {
            items = items.filter { $0.category == category }
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
        return items
    }

    static func similarStrength(to exercise: BuilderDraftExercise, limit: Int = 3) -> [CatalogExercise] {
        var matches = strength.filter {
            $0.name != exercise.name && $0.category == exercise.category && $0.type == exercise.type
        }
        if matches.count < limit {
            let extra = strength.filter {
                $0.name != exercise.name
                    && $0.category == exercise.category
                    && $0.type != exercise.type
                    && !matches.contains($0)
            }
            matches.append(contentsOf: extra)
        }
        if matches.count < limit {
            let extra = strength.filter {
                $0.name != exercise.name && $0.type == exercise.type && !matches.contains($0)
            }
            matches.append(contentsOf: extra)
        }
        return Array(matches.prefix(limit))
    }

    static func similarCardio(to exercise: BuilderDraftExercise, limit: Int = 3) -> [CardioOption] {
        Array(cardio.filter { $0.name != exercise.name }.prefix(limit))
    }
}
