import SwiftUI

struct SplashScreen: View {
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var ringOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.15, blue: 0.08),
                    Color(red: 0.02, green: 0.08, blue: 0.04),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle radial glow behind icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: glowRadius)
                .offset(y: -40)

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    // Spinning accent ring
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green.opacity(0.6), Color.green.opacity(0.05)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(ringRotation))
                        .opacity(ringOpacity)

                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 110, height: 110)

                        Circle()
                            .strokeBorder(Color.green.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 110, height: 110)

                        Image(systemName: "leaf.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, Color(red: 0.2, green: 0.9, blue: 0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                }

                VStack(spacing: 8) {
                    Text("ShelfScore")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(titleOpacity)

                    Text("Scan smarter. Eat better.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .opacity(taglineOpacity)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            // Icon entrance
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // Glow pulse
            withAnimation(.easeInOut(duration: 1.5).delay(0.2)) {
                glowRadius = 30
            }

            // Ring spin
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                ringOpacity = 1.0
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }

            // Title fade in
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                titleOpacity = 1.0
            }

            // Tagline fade in
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                taglineOpacity = 1.0
            }
        }
    }
}
