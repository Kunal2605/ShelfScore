import SwiftUI
import SwiftData

@main
struct ShelfScoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ScannedProduct.self)
    }
}

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
