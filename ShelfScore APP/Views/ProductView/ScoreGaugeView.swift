import SwiftUI

struct ScoreGaugeView: View {
    let score: Int
    let grade: HealthScore.Grade
    let animate: Bool

    private var progress: Double {
        animate ? Double(score) / 100.0 : 0
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)

            // Score arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            grade.color.opacity(0.4),
                            grade.color.opacity(0.7),
                            grade.color,
                            grade.color
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.7), value: animate)
                .shadow(color: grade.color.opacity(0.3), radius: 4, y: 0)

            // Score text
            VStack(spacing: 2) {
                Text("\(animate ? score : 0)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(gradeColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 1.0, dampingFraction: 0.7), value: animate)

                Text("/ 100")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                // Grade badge
                Text(grade.rawValue)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(grade.color)
                    )
                    .padding(.top, 4)
            }
        }
        .padding(16)
    }

    private var gradeColor: Color {
        grade.color
    }
}
