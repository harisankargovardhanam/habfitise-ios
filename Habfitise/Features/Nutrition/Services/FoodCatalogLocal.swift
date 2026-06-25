import Foundation

struct FoodCatalogEntry: Codable, Sendable {
    let name: String
    let aliases: [String]
    let servingDescription: String
    let caloriesLow: Int
    let caloriesMid: Int
    let caloriesHigh: Int
    let proteinLow: Int
    let proteinMid: Int
    let proteinHigh: Int
    let region: String

    enum CodingKeys: String, CodingKey {
        case name
        case aliases
        case servingDescription = "serving_description"
        case caloriesLow = "calories_low"
        case caloriesMid = "calories_mid"
        case caloriesHigh = "calories_high"
        case proteinLow = "protein_low"
        case proteinMid = "protein_mid"
        case proteinHigh = "protein_high"
        case region
    }
}

enum FoodCatalogLocal {
    private static let mealSeparators = [" with ", " and ", " plus ", " + ", " & ", ","]

    private static let typoCorrections: [String: String] = [
        "dosha": "dosa",
        "dosai": "dosa",
        "doshai": "dosa",
        "dhosa": "dosa",
        "chaya": "chai",
        "chaye": "chai",
        "chay": "chai",
        "chaay": "chai",
        "idly": "idli",
        "idlee": "idli",
        "biriyani": "biryani",
        "biriani": "biryani",
        "chapathi": "chapati",
        "chappati": "chapati",
    ]

    private static let entries: [FoodCatalogEntry] = [
        .init(name: "Coffee with milk", aliases: ["coffee with milk", "cup of coffee with milk", "one cup of coffee with milk", "coffee milk"], servingDescription: "1 cup (~240 ml)", caloriesLow: 30, caloriesMid: 45, caloriesHigh: 60, proteinLow: 2, proteinMid: 3, proteinHigh: 4, region: "global"),
        .init(name: "Black coffee", aliases: ["black coffee", "plain coffee", "espresso", "americano", "coffee without milk"], servingDescription: "1 cup (~240 ml)", caloriesLow: 0, caloriesMid: 5, caloriesHigh: 10, proteinLow: 0, proteinMid: 0, proteinHigh: 1, region: "global"),
        .init(name: "Latte", aliases: ["latte", "caffe latte", "coffee latte"], servingDescription: "1 cup (~240 ml)", caloriesLow: 90, caloriesMid: 120, caloriesHigh: 150, proteinLow: 4, proteinMid: 6, proteinHigh: 8, region: "global"),
        .init(name: "Milk tea (chai)", aliases: ["tea with sugar", "chai", "chaya", "chaye", "1 cup tea with sugar", "cup tea with sugar"], servingDescription: "1 cup (~240 ml)", caloriesLow: 70, caloriesMid: 90, caloriesHigh: 110, proteinLow: 2, proteinMid: 3, proteinHigh: 4, region: "south_asia"),
        .init(name: "Black tea with sugar", aliases: ["black tea", "tea sugar"], servingDescription: "1 cup (~240 ml)", caloriesLow: 25, caloriesMid: 40, caloriesHigh: 55, proteinLow: 0, proteinMid: 0, proteinHigh: 1, region: "global"),
        .init(name: "Idli", aliases: ["idly", "2 idli"], servingDescription: "2 pieces", caloriesLow: 60, caloriesMid: 78, caloriesHigh: 95, proteinLow: 2, proteinMid: 3, proteinHigh: 4, region: "south_asia"),
        .init(name: "Plain dosa", aliases: ["dosa", "dosha", "1 dosa"], servingDescription: "1 medium dosa", caloriesLow: 95, caloriesMid: 120, caloriesHigh: 145, proteinLow: 2, proteinMid: 3, proteinHigh: 4, region: "south_asia"),
        .init(name: "Chicken biryani", aliases: ["biryani", "chicken biriyani"], servingDescription: "1 plate (~350 g)", caloriesLow: 560, caloriesMid: 680, caloriesHigh: 820, proteinLow: 22, proteinMid: 28, proteinHigh: 34, region: "south_asia"),
        .init(name: "Dal tadka", aliases: ["dal", "yellow dal"], servingDescription: "1 cup", caloriesLow: 140, caloriesMid: 180, caloriesHigh: 220, proteinLow: 8, proteinMid: 10, proteinHigh: 12, region: "south_asia"),
        .init(name: "Roti / chapati", aliases: ["roti", "chapati"], servingDescription: "1 piece", caloriesLow: 55, caloriesMid: 70, caloriesHigh: 85, proteinLow: 2, proteinMid: 2, proteinHigh: 3, region: "south_asia"),
        .init(name: "White rice cooked", aliases: ["rice", "1 cup rice"], servingDescription: "1 cup cooked", caloriesLow: 180, caloriesMid: 206, caloriesHigh: 235, proteinLow: 3, proteinMid: 4, proteinHigh: 5, region: "global"),
        .init(name: "Boiled egg", aliases: ["egg", "1 egg", "2 eggs"], servingDescription: "1 large egg", caloriesLow: 62, caloriesMid: 78, caloriesHigh: 95, proteinLow: 5, proteinMid: 6, proteinHigh: 7, region: "global"),
        .init(name: "Paneer butter masala", aliases: ["paneer masala"], servingDescription: "1 cup", caloriesLow: 280, caloriesMid: 360, caloriesHigh: 440, proteinLow: 12, proteinMid: 14, proteinHigh: 17, region: "south_asia"),
        .init(name: "Samosa", aliases: ["1 samosa"], servingDescription: "1 piece", caloriesLow: 200, caloriesMid: 260, caloriesHigh: 320, proteinLow: 4, proteinMid: 5, proteinHigh: 6, region: "south_asia"),
    ]

    /// Single-food lookup (whole string).
    static func match(query: String, region: String) -> FoodCatalogEntry? {
        let corrected = correctTypo(query)
        if let direct = bestMatch(for: corrected, region: region) {
            return direct
        }

        let normalized = normalize(corrected)
        var best: (entry: FoodCatalogEntry, score: Int)?

        for entry in entries {
            let regionBoost = entry.region == region || entry.region == "global" ? 5 : 0
            for alias in entry.aliases.map(normalize) + [normalize(entry.name)] {
                if normalized.contains(alias), alias.count >= 4 {
                    let score = 75 + regionBoost + min(alias.count, 20)
                    if best == nil || score > best!.score {
                        best = (entry, score)
                    }
                }
            }
        }

        return best?.entry
    }

    /// Split "dosa with chai" and match every part in the on-device catalog.
    static func matchMeal(query: String, region: String) -> [FoodCatalogEntry]? {
        let parts = splitMeal(query)
        guard parts.count >= 2 else { return nil }

        var matched: [FoodCatalogEntry] = []
        for part in parts {
            guard let entry = match(query: part, region: region) else { return nil }
            matched.append(entry)
        }
        return matched
    }

    static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func splitMeal(_ value: String) -> [String] {
        var segments = [value.trimmingCharacters(in: .whitespacesAndNewlines)]
        for separator in mealSeparators {
            segments = segments.flatMap { splitCaseInsensitive($0, by: separator) }
        }
        let parts = segments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
        return parts.count >= 2 ? parts : []
    }

    private static func splitCaseInsensitive(_ value: String, by separator: String) -> [String] {
        var parts: [String] = []
        var remaining = value[...]

        while let range = remaining.range(of: separator, options: .caseInsensitive) {
            parts.append(String(remaining[..<range.lowerBound]))
            remaining = remaining[range.upperBound...]
        }
        parts.append(String(remaining))
        return parts
    }

    private static func correctTypo(_ value: String) -> String {
        let normalized = normalize(value)
        let tokens = normalized.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return normalized }

        let corrected = tokens.map { token -> String in
            typoCorrections[token] ?? token
        }
        return corrected.joined(separator: " ")
    }

    private static func bestMatch(for query: String, region: String) -> FoodCatalogEntry? {
        let normalized = normalize(query)
        guard normalized.count >= 2 else { return nil }

        var best: (entry: FoodCatalogEntry, score: Int)?

        for entry in entries {
            let regionBoost = entry.region == region || entry.region == "global" ? 5 : 0
            let candidates = [normalize(entry.name)] + entry.aliases.map(normalize)
            for candidate in candidates {
                let score = scoreMatch(query: normalized, candidate: candidate) + regionBoost
                if score >= 55, best == nil || score > best!.score {
                    best = (entry, score)
                }
            }
        }

        return best?.entry
    }

    private static func scoreMatch(query: String, candidate: String) -> Int {
        if query == candidate { return 100 }
        if candidate.contains(query) || query.contains(candidate) { return 80 }
        let queryTokens = Set(query.split(separator: " ").map(String.init))
        let candidateTokens = candidate.split(separator: " ").map(String.init)
        guard !candidateTokens.isEmpty else { return 0 }
        let overlap = candidateTokens.filter { queryTokens.contains($0) }.count
        return Int((Double(overlap) / Double(candidateTokens.count)) * 70)
    }
}
