import SwiftUI
import SwiftData

struct HistoryScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedProduct.scannedAt, order: .reverse)
    private var scannedProducts: [ScannedProduct]

    @State private var selectedProduct: Product?
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            Group {
                if scannedProducts.isEmpty {
                    emptyState
                } else {
                    productList
                }
            }
            .navigationTitle("History")
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showResult) {
            if let product = selectedProduct {
                NavigationStack {
                    ProductResultScreen(product: product)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showResult = false }
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.06))
                    .frame(width: 120, height: 120)

                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.green.opacity(0.35))
            }

            VStack(spacing: 6) {
                Text("No Scans Yet")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Scan a product barcode to\nsee your history here")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Product List
    private var productList: some View {
        List {
            ForEach(scannedProducts) { scanned in
                Button {
                    loadAndShow(scanned)
                } label: {
                    historyRow(scanned)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteProducts)
        }
        .listStyle(.plain)
    }

    // MARK: - History Row
    private func historyRow(_ scanned: ScannedProduct) -> some View {
        let grade = HealthScore.Grade.from(score: scanned.score)

        return HStack(spacing: 12) {
            // Score badge
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(grade.color.opacity(0.12))
                    .frame(width: 50, height: 50)

                VStack(spacing: 0) {
                    Text(grade.rawValue)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(grade.color)

                    Text("\(scanned.score)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(grade.color.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(scanned.name.isEmpty ? "Unknown Product" : scanned.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !scanned.brand.isEmpty {
                    Text(scanned.brand)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(scanned.scannedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.systemGray5).opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Actions
    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(scannedProducts[index])
        }
    }

    private func loadAndShow(_ scanned: ScannedProduct) {
        Task {
            do {
                let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: scanned.barcode)
                await MainActor.run {
                    selectedProduct = product
                    showResult = true
                }
            } catch {
                let nutrition = NutritionFacts(
                    calories: 0, fat: 0, saturatedFat: 0, carbohydrates: 0,
                    sugars: 0, fiber: 0, proteins: 0, salt: 0, sodium: 0
                )
                let healthScore = HealthScore(
                    score: scanned.score,
                    grade: HealthScore.Grade.from(score: scanned.score),
                    positives: [],
                    negatives: []
                )
                let product = Product(
                    id: scanned.barcode,
                    name: scanned.name,
                    brand: scanned.brand,
                    imageURL: nil,
                    nutrition: nutrition,
                    nutriscoreGrade: nil,
                    novaGroup: nil,
                    ingredients: nil,
                    allergens: [],
                    additives: [],
                    categories: nil,
                    quantity: nil,
                    healthScore: healthScore
                )
                await MainActor.run {
                    selectedProduct = product
                    showResult = true
                }
            }
        }
    }
}

// MARK: - SwiftData Model
@Model
final class ScannedProduct {
    var barcode: String
    var name: String
    var brand: String
    var score: Int
    var scannedAt: Date

    init(barcode: String, name: String, brand: String, score: Int, scannedAt: Date = .now) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.score = score
        self.scannedAt = scannedAt
    }

    convenience init(from product: Product) {
        self.init(
            barcode: product.id,
            name: product.displayName,
            brand: product.brand,
            score: product.healthScore.score
        )
    }
}
