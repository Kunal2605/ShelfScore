import SwiftUI

struct NutrientRowView: View {
    let name: String
    let value: String
    let level: NutritionFacts.NutrientLevel

    var body: some View {
        HStack(spacing: 8) {
            // Color indicator dot
            Circle()
                .fill(levelColor)
                .frame(width: 8, height: 8)

            Text(name)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))

            // Level badge
            Text(level.rawValue)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(levelColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(levelColor.opacity(0.1))
                )
        }
        .padding(.vertical, 5)
    }

    private var levelColor: Color {
        switch level {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }
}
