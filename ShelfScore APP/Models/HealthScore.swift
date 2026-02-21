import SwiftUI

/// Health score for a product (0-100 scale)
struct HealthScore {
    let score: Int          // 0-100
    let grade: Grade        // A-E
    let positives: [ScoreFactor]
    let negatives: [ScoreFactor]

    enum Grade: String, CaseIterable {
        case a = "A"
        case b = "B"
        case c = "C"
        case d = "D"
        case e = "E"

        var color: Color {
            switch self {
            case .a: return Color(red: 0.13, green: 0.77, blue: 0.37) // Emerald green
            case .b: return Color(red: 0.55, green: 0.82, blue: 0.22) // Lime green
            case .c: return Color(red: 1.0, green: 0.76, blue: 0.03)  // Amber yellow
            case .d: return Color(red: 1.0, green: 0.49, blue: 0.05)  // Orange
            case .e: return Color(red: 0.93, green: 0.26, blue: 0.21) // Red
            }
        }

        var label: String {
            switch self {
            case .a: return "Excellent"
            case .b: return "Good"
            case .c: return "Average"
            case .d: return "Poor"
            case .e: return "Bad"
            }
        }

        static func from(score: Int) -> Grade {
            switch score {
            case 80...100: return .a  // Excellent  — genuinely healthy
            case 65..<80:  return .b  // Good       — above average (raised from 60)
            case 45..<65:  return .c  // Average    — mixed nutritional profile
            case 22..<45:  return .d  // Poor       — significant concerns
            default:       return .e  // Bad        — avoid or limit
            }
        }
    }
}

/// A contributing factor to the health score
struct ScoreFactor: Identifiable {
    let id = UUID()
    let name: String
    let impact: Int   // points added or subtracted
    let detail: String
}
