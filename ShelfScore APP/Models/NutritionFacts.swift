import Foundation

/// Nutrition facts per 100g
struct NutritionFacts {
    let calories: Double      // kcal per 100g
    let fat: Double           // g per 100g
    let saturatedFat: Double  // g per 100g
    let carbohydrates: Double // g per 100g
    let sugars: Double        // g per 100g
    let fiber: Double         // g per 100g
    let proteins: Double      // g per 100g
    let salt: Double          // g per 100g
    let sodium: Double        // g per 100g

    /// Rating for a given nutrient: low, moderate, or high
    enum NutrientLevel: String {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"

        var emoji: String {
            switch self {
            case .low: return "🟢"
            case .moderate: return "🟡"
            case .high: return "🔴"
            }
        }
    }

    var fatLevel: NutrientLevel {
        if fat <= 3 { return .low }
        if fat <= 17.5 { return .moderate }
        return .high
    }

    var saturatedFatLevel: NutrientLevel {
        if saturatedFat <= 1.5 { return .low }
        if saturatedFat <= 5 { return .moderate }
        return .high
    }

    var sugarsLevel: NutrientLevel {
        if sugars <= 5 { return .low }
        if sugars <= 22.5 { return .moderate }
        return .high
    }

    var saltLevel: NutrientLevel {
        if salt <= 0.3 { return .low }
        if salt <= 1.5 { return .moderate }
        return .high
    }

    var fiberLevel: NutrientLevel {
        if fiber >= 6 { return .low }  // high fiber is good → "low" risk
        if fiber >= 3 { return .moderate }
        return .high
    }

    var proteinLevel: NutrientLevel {
        if proteins >= 8 { return .low }  // high protein is good → "low" risk
        if proteins >= 4 { return .moderate }
        return .high
    }

    /// All nutrient rows for display
    var displayRows: [(name: String, value: String, level: NutrientLevel)] {
        [
            ("Calories", "\(Int(calories)) kcal", caloriesLevel),
            ("Fat", String(format: "%.1fg", fat), fatLevel),
            ("Saturated Fat", String(format: "%.1fg", saturatedFat), saturatedFatLevel),
            ("Carbohydrates", String(format: "%.1fg", carbohydrates), .moderate),
            ("Sugars", String(format: "%.1fg", sugars), sugarsLevel),
            ("Fiber", String(format: "%.1fg", fiber), fiberLevel),
            ("Proteins", String(format: "%.1fg", proteins), proteinLevel),
            ("Salt", String(format: "%.2fg", salt), saltLevel),
        ]
    }

    private var caloriesLevel: NutrientLevel {
        if calories <= 100 { return .low }
        if calories <= 300 { return .moderate }
        return .high
    }
}
