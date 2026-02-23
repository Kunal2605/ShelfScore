import SwiftUI
import SwiftData

struct GroceryListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.addedAt, order: .reverse) private var allItems: [GroceryItem]

    @State private var showAddSheet = false
    @State private var selectedProduct: Product?

    private var needToBuy: [GroceryItem] { allItems.filter { !$0.isBought } }
    private var bought: [GroceryItem] { allItems.filter { $0.isBought } }

    var body: some View {
        NavigationStack {
            Group {
                if allItems.isEmpty {
                    emptyState
                } else {
                    groceryList
                }
            }
            .navigationTitle("Grocery List")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.green)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                GrocerySearchSheet()
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedProduct) { product in
                NavigationStack {
                    ProductResultScreen(product: product)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { selectedProduct = nil }
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Grocery List

    private var groceryList: some View {
        List {
            // Need to Buy section
            if !needToBuy.isEmpty {
                Section {
                    ForEach(needToBuy) { item in
                        GroceryListRow(item: item)
                            .listRowBackground(Color.white)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .contentShape(Rectangle())
                            .onTapGesture { loadAndShow(item) }
                    }
                    .onDelete { offsets in deleteItems(needToBuy, offsets: offsets) }
                } header: {
                    sectionHeader(
                        title: "Need to Buy",
                        count: needToBuy.count,
                        icon: "cart.fill",
                        color: .orange
                    )
                }
            }

            // Bought section
            if !bought.isEmpty {
                Section {
                    ForEach(bought) { item in
                        GroceryListRow(item: item)
                            .listRowBackground(Color.white)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .contentShape(Rectangle())
                            .onTapGesture { loadAndShow(item) }
                    }
                    .onDelete { offsets in deleteItems(bought, offsets: offsets) }
                } header: {
                    sectionHeader(
                        title: "Bought",
                        count: bought.count,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer()
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(color))
        }
        .padding(.bottom, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "cart")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.green.opacity(0.4))
            }

            VStack(spacing: 6) {
                Text("Your List is Empty")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Tap + to search for products\nand add them to your grocery list")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Products")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.green))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func deleteItems(_ section: [GroceryItem], offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(section[index])
        }
        try? modelContext.save()
    }

    private func loadAndShow(_ item: GroceryItem) {
        guard !item.isCustom else { return }
        let context = modelContext
        Task {
            do {
                let product = try await OpenFoodFactsService.shared.fetchProduct(
                    barcode: item.barcode,
                    modelContext: context
                )
                await MainActor.run { selectedProduct = product }
            } catch {
                // Build a minimal product from stored data so the detail screen still opens
                let nutrition = NutritionFacts(
                    calories: 0, fat: 0, saturatedFat: 0,
                    carbohydrates: 0, sugars: 0, fiber: 0,
                    proteins: 0, salt: 0, sodium: 0
                )
                let grade = HealthScore.Grade.from(score: item.healthScore)
                let health = HealthScore(score: item.healthScore, grade: grade, positives: [], negatives: [])
                let product = Product(
                    id: item.barcode, name: item.name, brand: item.brand,
                    imageURL: item.imageURL, nutrition: nutrition,
                    nutriscoreGrade: nil, novaGroup: nil, ingredients: nil,
                    allergens: [], additives: [], categories: nil,
                    quantity: nil, healthScore: health
                )
                await MainActor.run { selectedProduct = product }
            }
        }
    }
}
