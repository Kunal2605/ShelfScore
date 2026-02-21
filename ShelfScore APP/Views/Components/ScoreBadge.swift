import SwiftUI

struct ScoreBadge: View {
    let grade: HealthScore.Grade
    let score: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(grade.color.opacity(0.12))
                .frame(width: 50, height: 50)

            VStack(spacing: 0) {
                Text(grade.rawValue)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(grade.color)

                Text("\(score)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(grade.color.opacity(0.7))
            }
        }
    }
}
