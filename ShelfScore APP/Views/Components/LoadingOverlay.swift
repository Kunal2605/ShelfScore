import SwiftUI

struct LoadingOverlay: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.9
    @State private var dotOpacity: Double = 0.3

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    // Spinner ring
                    Circle()
                        .trim(from: 0, to: 0.65)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))

                    // Icon
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                }

                VStack(spacing: 8) {
                    Text("Looking up product")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(.green)
                                .frame(width: 5, height: 5)
                                .opacity(dotOpacity)
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                    value: dotOpacity
                                )
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                scale = 1.0
            }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            dotOpacity = 1.0
        }
    }
}
