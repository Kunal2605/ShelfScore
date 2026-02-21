import Foundation

/// Calculates a health score (0-100) based on the Nutri-Score 2023 methodology
/// adapted to a consumer-friendly 0-100 scale.
///
/// **How it works:**
/// 1. Compute negative points (N) from energy, sugars, saturated fat, salt — max 55
/// 2. Compute positive points (P) from fiber, protein, Nutri-Score grade — max 17
/// 3. Raw Nutri-Score = N − P  (lower = healthier, range −17 to +55)
/// 4. Map to 0-100:  baseScore = 100 − (rawScore × 1.39)
/// 5. Apply NOVA processing modifier (±5) and additive modifier (±4)
/// 6. Clamp to 0-100
struct HealthScoreCalculator {

    // MARK: - Public API

    /// Calculate health score from product data
    static func calculate(
        nutrition: NutritionFacts,
        novaGroup: Int?,
        additives: [String],
        nutriscoreGrade: String?
    ) -> HealthScore {
        var positives: [ScoreFactor] = []
        var negatives: [ScoreFactor] = []

        // ── Step 1: Negative Points (max 55) ────────────────────────

        let energyPts = energyPoints(nutrition.calories)
        if energyPts > 0 {
            negatives.append(ScoreFactor(
                name: "Calories",
                impact: -energyPts,
                detail: "\(Int(nutrition.calories)) kcal/100g"
            ))
        }

        let sugarPts = sugarPoints(nutrition.sugars)
        if sugarPts > 0 {
            negatives.append(ScoreFactor(
                name: "Sugars",
                impact: -sugarPts,
                detail: String(format: "%.1fg/100g", nutrition.sugars)
            ))
        }

        let satFatPts = saturatedFatPoints(nutrition.saturatedFat)
        if satFatPts > 0 {
            negatives.append(ScoreFactor(
                name: "Saturated Fat",
                impact: -satFatPts,
                detail: String(format: "%.1fg/100g", nutrition.saturatedFat)
            ))
        }

        let saltPts = saltPoints(nutrition.salt)
        if saltPts > 0 {
            negatives.append(ScoreFactor(
                name: "Salt",
                impact: -saltPts,
                detail: String(format: "%.2fg/100g", nutrition.salt)
            ))
        }

        let totalNegative = energyPts + sugarPts + satFatPts + saltPts

        // ── Step 2: Positive Points (max 17) ────────────────────────

        let fiberPts = fiberPoints(nutrition.fiber)
        if fiberPts > 0 {
            positives.append(ScoreFactor(
                name: "Fiber",
                impact: fiberPts,
                detail: String(format: "%.1fg/100g", nutrition.fiber)
            ))
        }

        let proteinPts = proteinPoints(nutrition.proteins)
        if proteinPts > 0 {
            positives.append(ScoreFactor(
                name: "Protein",
                impact: proteinPts,
                detail: String(format: "%.1fg/100g", nutrition.proteins)
            ))
        }

        let gradeBoost = nutriscoreGradeBoost(nutriscoreGrade)
        if gradeBoost > 0 {
            positives.append(ScoreFactor(
                name: "Nutri-Score Grade",
                impact: gradeBoost,
                detail: "Grade \(nutriscoreGrade?.uppercased() ?? "?")"
            ))
        }

        let totalPositive = fiberPts + proteinPts + gradeBoost

        // ── Step 3: NOVA Processing Modifier ────────────────────────

        let novaModifier = novaModifierPoints(novaGroup)
        if novaModifier > 0 {
            positives.append(ScoreFactor(
                name: "Minimal Processing",
                impact: novaModifier,
                detail: novaGroup.map { "NOVA Group \($0)" } ?? "Unknown"
            ))
        } else if novaModifier < 0 {
            negatives.append(ScoreFactor(
                name: "Ultra-Processing",
                impact: novaModifier,
                detail: novaGroup.map { "NOVA Group \($0)" } ?? "Unknown"
            ))
        }

        // ── Step 4: Additive Modifier ───────────────────────────────

        let additiveModifier = additiveModifierPoints(additives.count)
        if additiveModifier > 0 {
            positives.append(ScoreFactor(
                name: "No Additives",
                impact: additiveModifier,
                detail: "0 additives"
            ))
        } else if additiveModifier < 0 {
            negatives.append(ScoreFactor(
                name: "Additives",
                impact: additiveModifier,
                detail: "\(additives.count) additive(s)"
            ))
        }

        // ── Step 5: Final Score ──────────────────────────────────────

        // Raw Nutri-Score: lower = healthier (range: -17 to +55)
        let rawNutriScore = totalNegative - totalPositive

        // Map to 0-100 scale where 100 = healthiest
        // Range of rawNutriScore is -17 to 55 = 72 points
        // Scale factor: 100 / 72 ≈ 1.39
        let baseScore = 100.0 - (Double(rawNutriScore) * 1.39)
        let adjustedScore = baseScore + Double(novaModifier) + Double(additiveModifier)
        let clampedScore = max(0, min(100, Int(adjustedScore.rounded())))

        let grade = HealthScore.Grade.from(score: clampedScore)

        return HealthScore(
            score: clampedScore,
            grade: grade,
            positives: positives,
            negatives: negatives
        )
    }

    // MARK: - Negative Point Tables (Nutri-Score 2023)

    /// Energy: 0-10 points, thresholds at 80 kcal increments
    private static func energyPoints(_ kcal: Double) -> Int {
        let thresholds: [Double] = [80, 160, 240, 320, 400, 480, 560, 640, 720, 800]
        return pointsFromThresholds(kcal, thresholds: thresholds, max: 10)
    }

    /// Sugars: 0-15 points, 1g increments (Nutri-Score 2023 raised max from 10→15)
    private static func sugarPoints(_ grams: Double) -> Int {
        // Each gram above 0 adds a point, up to 15
        let pts = Int(grams)
        return min(15, max(0, pts))
    }

    /// Saturated fat: 0-10 points, 1g increments
    private static func saturatedFatPoints(_ grams: Double) -> Int {
        let thresholds: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        return pointsFromThresholds(grams, thresholds: thresholds, max: 10)
    }

    /// Salt: 0-20 points, 0.2g increments (Nutri-Score 2023 raised max from 10→20)
    private static func saltPoints(_ grams: Double) -> Int {
        // Each 0.2g of salt = 1 point, max 20
        let pts = Int(grams / 0.2)
        return min(20, max(0, pts))
    }

    // MARK: - Positive Point Tables (Nutri-Score 2023)

    /// Fiber: 0-7 points (Nutri-Score 2023 thresholds)
    private static func fiberPoints(_ grams: Double) -> Int {
        let thresholds: [Double] = [0.9, 1.9, 2.8, 3.7, 4.7, 5.6, 6.6]
        return pointsFromThresholds(grams, thresholds: thresholds, max: 7)
    }

    /// Protein: 0-7 points (Nutri-Score 2023: max raised from 5→7)
    private static func proteinPoints(_ grams: Double) -> Int {
        let thresholds: [Double] = [1.6, 3.2, 4.8, 6.4, 8.0, 9.6, 11.2]
        return pointsFromThresholds(grams, thresholds: thresholds, max: 7)
    }

    /// Nutri-Score grade boost: uses the API's grade as a validation signal
    private static func nutriscoreGradeBoost(_ grade: String?) -> Int {
        switch grade?.lowercased() {
        case "a": return 3
        case "b": return 2
        case "c": return 1
        default:  return 0
        }
    }

    // MARK: - NOVA Modifier

    /// NOVA group modifier: balanced bonus/penalty
    private static func novaModifierPoints(_ group: Int?) -> Int {
        switch group {
        case 1:  return 5    // Unprocessed → strong bonus
        case 2:  return 2    // Culinary ingredients → small bonus
        case 3:  return 0    // Processed → neutral
        case 4:  return -5   // Ultra-processed → moderate penalty
        default: return -2   // Unknown → slight penalty
        }
    }

    // MARK: - Additive Modifier

    /// Tiered additive modifier based on count
    private static func additiveModifierPoints(_ count: Int) -> Int {
        switch count {
        case 0:     return 2     // No additives → small bonus
        case 1...2: return 0     // Few additives → neutral
        case 3...5: return -2    // Several additives → small penalty
        default:    return -4    // Many additives → moderate penalty
        }
    }

    // MARK: - Helpers

    /// Generic threshold-based scoring: returns how many thresholds the value exceeds
    private static func pointsFromThresholds(_ value: Double, thresholds: [Double], max: Int) -> Int {
        var pts = 0
        for threshold in thresholds {
            if value > threshold {
                pts += 1
            } else {
                break
            }
        }
        return min(max, pts)
    }
}
