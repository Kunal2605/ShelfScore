import Foundation

/// Calculates a health score (0-100) based on nutritional quality,
/// food processing level, and additive load.
///
/// **How it works:**
/// 1. Compute negative points (N) from energy, sugars, saturated fat, salt — max 55
/// 2. Compute positive points (P) from fiber, protein — max 14
/// 3. Raw score = N − P  (lower = healthier, range −14 to +55)
/// 4. Map to 0-100:  baseScore = 100 − (rawScore × 1.5)
/// 5. Apply NOVA processing modifier (−15 to +8)
/// 6. Apply additive modifier (−12 to +3)
/// 7. Clamp to 0-100
///
/// **Key design decisions vs. original:**
/// - Removed Nutri-Score grade boost (circular dependency, inflated scores)
/// - Scale factor raised 1.39 → 1.5 (stricter base penalties)
/// - NOVA 4 penalty raised −5 → −15 (ultra-processed foods cause measurable harm)
/// - NOVA 3 now carries a −3 penalty (processed foods are not neutral)
/// - Additive penalty raised −4 → −12 max (more additives = more concern)
struct HealthScoreCalculator {

    // MARK: - Public API

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

        // ── Step 2: Positive Points (max 14) ────────────────────────

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

        let totalPositive = fiberPts + proteinPts

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
                name: novaGroup == 4 ? "Ultra-Processed" : "Processed Food",
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

        // Raw score range: −14 to +55 (lower = healthier)
        let rawScore = totalNegative - totalPositive

        // Map to 0-100 scale (scale factor 1.5 is intentionally strict)
        let baseScore = 100.0 - (Double(rawScore) * 1.5)
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

    // MARK: - Negative Point Tables

    /// Energy: 0-10 points, thresholds at 80 kcal increments
    private static func energyPoints(_ kcal: Double) -> Int {
        let thresholds: [Double] = [80, 160, 240, 320, 400, 480, 560, 640, 720, 800]
        return pointsFromThresholds(kcal, thresholds: thresholds, max: 10)
    }

    /// Sugars: 0-15 points, 1g increments
    private static func sugarPoints(_ grams: Double) -> Int {
        let pts = Int(grams)
        return min(15, max(0, pts))
    }

    /// Saturated fat: 0-10 points, 1g increments
    private static func saturatedFatPoints(_ grams: Double) -> Int {
        let thresholds: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        return pointsFromThresholds(grams, thresholds: thresholds, max: 10)
    }

    /// Salt: 0-20 points, 0.2g increments
    private static func saltPoints(_ grams: Double) -> Int {
        let pts = Int(grams / 0.2)
        return min(20, max(0, pts))
    }

    // MARK: - Positive Point Tables

    /// Fiber: 0-7 points
    private static func fiberPoints(_ grams: Double) -> Int {
        let thresholds: [Double] = [0.9, 1.9, 2.8, 3.7, 4.7, 5.6, 6.6]
        return pointsFromThresholds(grams, thresholds: thresholds, max: 7)
    }

    /// Protein: 0-7 points
    private static func proteinPoints(_ grams: Double) -> Int {
        let thresholds: [Double] = [1.6, 3.2, 4.8, 6.4, 8.0, 9.6, 11.2]
        return pointsFromThresholds(grams, thresholds: thresholds, max: 7)
    }

    // MARK: - NOVA Modifier
    //
    // Evidence shows ultra-processed foods (NOVA 4) are associated with
    // increased risk of obesity, diabetes, cardiovascular disease, and cancer
    // independent of their nutritional composition. The large −15 penalty
    // reflects this independent health risk.

    private static func novaModifierPoints(_ group: Int?) -> Int {
        switch group {
        case 1:  return  8   // Unprocessed / minimally processed — significant bonus
        case 2:  return  3   // Processed culinary ingredients — small bonus
        case 3:  return -3   // Processed foods — small penalty
        case 4:  return -15  // Ultra-processed — large penalty (independent of nutrients)
        default: return -5   // Unknown processing level — moderate penalty
        }
    }

    // MARK: - Additive Modifier

    private static func additiveModifierPoints(_ count: Int) -> Int {
        switch count {
        case 0:     return  3   // No additives — bonus
        case 1...2: return -2   // Few additives — small penalty
        case 3...5: return -6   // Several additives — moderate penalty
        default:    return -12  // Many additives — large penalty
        }
    }

    // MARK: - Helpers

    private static func pointsFromThresholds(_ value: Double, thresholds: [Double], max: Int) -> Int {
        var pts = 0
        for threshold in thresholds {
            if value > threshold { pts += 1 } else { break }
        }
        return min(max, pts)
    }
}
