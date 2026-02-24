import SwiftUI
import SwiftData

@main
struct ShelfScoreApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([ScannedProduct.self, CachedProduct.self, GroceryItem.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            // Schema migration failed — wipe the store and start fresh.
            // This is safe in development; all scan history will be lost once
            // but the app will launch correctly on every subsequent run.
            let supportDir = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            for ext in ["", ".shm", ".wal"] {
                try? FileManager.default.removeItem(
                    at: supportDir.appendingPathComponent("default.store\(ext)")
                )
            }
            // Re-create with a blank database
            container = try! ModelContainer(for: schema)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
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

            SearchScreen()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            RecipeListScreen()
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }

            GroceryListScreen()
                .tabItem {
                    Label("Grocery List", systemImage: "cart.fill")
                }

            HistoryScreen()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(.green)
        .preferredColorScheme(.light)
    }

    private func saveProduct(_ product: Product) {
        let scanned = ScannedProduct(from: product)
        modelContext.insert(scanned)
        try? modelContext.save()
    }
}
