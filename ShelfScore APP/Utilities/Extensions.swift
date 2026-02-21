import SwiftUI

// MARK: - Color Extensions
extension Color {
    static func scoreColor(for score: Int) -> Color {
        HealthScore.Grade.from(score: score).color
    }

    static let shelfGreen = Color(red: 0.13, green: 0.77, blue: 0.37)
}

// MARK: - View Extensions
extension View {
    /// Animate view entry with slide-up and fade
    func slideUp(delay: Double = 0, animate: Bool) -> some View {
        self
            .offset(y: animate ? 0 : 20)
            .opacity(animate ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(delay), value: animate)
    }
}

// MARK: - Product Image Placeholder
@ViewBuilder
func productImagePlaceholder() -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.systemGray6))
            .frame(width: 72, height: 72)

        Image(systemName: "takeoutbag.and.cup.and.straw")
            .font(.system(size: 24))
            .foregroundStyle(.quaternary)
    }
}

// MARK: - Date Formatting
extension Date {
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
