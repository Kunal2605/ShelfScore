import SwiftUI
import SwiftData

@main
struct ShelfScoreApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [ScannedProduct.self, CachedProduct.self])
    }
}

// MARK: - Root View (Splash → Main)
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashScreen()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
}

// MARK: - Main Content
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            ScannerScreen(onProductScanned: { product in
                saveProduct(product)
            })
            .tabItem {
                Label("Scan", systemImage: "barcode.viewfinder")
            }

            HistoryScreen()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(.green)
    }

    private func saveProduct(_ product: Product) {
        let scanned = ScannedProduct(from: product)
        modelContext.insert(scanned)
        try? modelContext.save()
    }
}
