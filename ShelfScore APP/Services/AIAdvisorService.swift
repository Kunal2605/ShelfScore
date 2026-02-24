import Foundation

// Foundation Models is only available on iOS 26+ with Apple Intelligence.
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
@Generable
private struct GeneratedInsight {
    @Guide(description: "1–2 sentence explanation of this product's health score for a grocery shopper. Be specific about the main nutritional factors driving the score.")
    var summary: String

    @Guide(description: "One short, actionable shopping tip based on this product's weakest nutritional area. Start with an action verb.")
    var tip: String
}
#endif

// MARK: - Insight Source

enum InsightSource {
    case appleIntelligence   // iOS 26+, Apple Intelligence on-device model
    case onDeviceLLM         // llama.cpp via LLM.swift (any device, downloaded model)
    case ruleBased           // deterministic fallback, always available
}

// MARK: - ProductInsight

struct ProductInsight {
    let summary: String
    let tip: String
    let source: InsightSource

    var isAIPowered: Bool { source != .ruleBased }

    var badgeLabel: String {
        switch source {
        case .appleIntelligence: return "Apple Intelligence"
        case .onDeviceLLM:       return "On-Device AI"
        case .ruleBased:         return "Smart Suggestion"
        }
    }

    var badgeIcon: String {
        switch source {
        case .appleIntelligence: return "apple.intelligence"
        case .onDeviceLLM:       return "brain.head.profile"
        case .ruleBased:         return "cpu"
        }
    }
}

// MARK: - AIAdvisorService

final class AIAdvisorService {
    static let shared = AIAdvisorService()
    private init() {}

    /// Priority order:
    ///   1. Apple Intelligence (iOS 26+)
    ///   2. On-device llama.cpp (if model downloaded & loaded)
    ///   3. Rule-based fallback (always available)
    func getProductInsight(for product: Product) async -> ProductInsight {
        // 1. Apple Intelligence
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if SystemLanguageModel.default.availability == .available {
                if let insight = await aiPoweredInsight(for: product) {
                    return insight
                }
            }
        }
        #endif

        // 2. On-device llama.cpp
        if LlamaAdvisorService.shared.isModelLoaded {
            if let insight = await LlamaAdvisorService.shared.getInsight(for: product) {
                return insight
            }
        }

        // 3. Rule-based
        return ruleBasedInsight(for: product)
    }

    // MARK: - Apple Intelligence Path (iOS 26+)

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func aiPoweredInsight(for product: Product) async -> ProductInsight? {
        let session = LanguageModelSession(instructions: """
            You are a concise nutrition advisor inside a grocery health-scoring app.
            Users scan barcodes and receive a 0–100 health score. Your job is to explain
            that score clearly and give one practical tip.
            Keep the summary to 1–2 short sentences. Keep the tip under 15 words.
            Do not repeat the score number in the tip. Be specific, not generic.
            """)
        do {
            let result = try await session.respond(
                to: buildPrompt(for: product),
                generating: GeneratedInsight.self
            )
            return ProductInsight(
                summary: result.content.summary,
                tip: result.content.tip,
                source: .appleIntelligence
            )
        } catch {
            return nil
        }
    }
    #endif

    private func buildPrompt(for product: Product) -> String {
        let negatives = product.healthScore.negatives.prefix(2)
            .map { "\($0.name): \($0.detail)" }.joined(separator: "; ")
        let positives = product.healthScore.positives.prefix(2)
            .map { $0.name }.joined(separator: ", ")
        let nova = product.novaGroup.map { "Processing Level (NOVA \($0))" } ?? ""

        return """
        Product: \(product.displayName)\(product.brand.isEmpty ? "" : " by \(product.brand)")
        Health Score: \(product.healthScore.score)/100 — Grade \(product.healthScore.grade.rawValue)
        Per 100g: \(Int(product.nutrition.calories)) kcal, \
        Sugar \(String(format: "%.1f", product.nutrition.sugars))g, \
        Saturated Fat \(String(format: "%.1f", product.nutrition.saturatedFat))g, \
        Salt \(String(format: "%.2f", product.nutrition.salt))g, \
        Fiber \(String(format: "%.1f", product.nutrition.fiber))g, \
        Protein \(String(format: "%.1f", product.nutrition.proteins))g
        \(nova)
        \(negatives.isEmpty ? "" : "Main issues: \(negatives)")
        \(positives.isEmpty ? "" : "Positives: \(positives)")
        \(product.additives.count > 0 ? "Additives: \(product.additives.count)" : "")
        """
    }

    // MARK: - Rule-Based Fallback (iOS 17+, always available)

    func ruleBasedInsight(for product: Product) -> ProductInsight {
        let grade = product.healthScore.grade
        let topNeg = product.healthScore.negatives.first
        let topTwo = product.healthScore.negatives.prefix(2).map { $0.name.lowercased() }
        let issueList = topTwo.joined(separator: " and ")
        let name = product.displayName
        let score = product.healthScore.score

        let summary: String
        switch grade {
        case .a:
            summary = "\(name) is an excellent choice with a score of \(score)/100. It scores well across all nutritional factors with low negatives."
        case .b:
            if let w = topNeg {
                summary = "A good product (\(score)/100). The main area to watch is \(w.name.lowercased()) (\(w.detail))."
            } else {
                summary = "A solid nutritional choice with a score of \(score)/100 — above average in its category."
            }
        case .c:
            if let w = topNeg {
                summary = "Average nutrition for \(name) (\(score)/100). The main concern is \(w.name.lowercased()) — \(w.detail)."
            } else {
                summary = "\(name) has a middling score of \(score)/100 with room to improve its nutritional profile."
            }
        case .d:
            summary = "\(name) scores below average at \(score)/100, driven by high \(issueList.isEmpty ? "levels of unhealthy nutrients" : issueList)."
        case .e:
            summary = "This product scores poorly at \(score)/100. High \(issueList.isEmpty ? "unhealthy nutrient levels" : issueList) are the main concerns — consider alternatives."
        }

        let tip = buildTip(for: topNeg?.name ?? "", novaGroup: product.novaGroup, additiveCount: product.additives.count)
        return ProductInsight(summary: summary, tip: tip, source: .ruleBased)
    }

    private func buildTip(for factorName: String, novaGroup: Int?, additiveCount: Int) -> String {
        let lower = factorName.lowercased()
        if lower.contains("sugar") {
            return "Look for products with under 5g of sugar per 100g."
        } else if lower.contains("saturated") || lower.contains("fat") {
            return "Choose products with under 1.5g of saturated fat per 100g."
        } else if lower.contains("salt") || lower.contains("sodium") {
            return "Aim for products with under 0.3g of salt per 100g."
        } else if lower.contains("energy") || lower.contains("calori") {
            return "Compare calorie density with similar products in this category."
        } else if lower.contains("additive") || lower.contains("nova") || lower.contains("process") {
            return "Prefer minimally processed alternatives (NOVA group 1 or 2)."
        } else if let nova = novaGroup, nova >= 4 {
            return "This product is ultra-processed. Look for less processed alternatives."
        } else if additiveCount > 3 {
            return "Look for products with a shorter, cleaner ingredient list."
        } else {
            return "Compare with similar products in this category for a healthier option."
        }
    }
}
