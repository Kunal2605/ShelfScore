import SwiftUI
import SwiftData

struct RecipeDetailScreen: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var fullRecipe: Recipe?
    @State private var isLoading = true
    @State private var addedIDs: Set<Int> = []
    @State private var showAddedBanner = false

    private var displayRecipe: Recipe { fullRecipe ?? recipe }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                contentSection
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(displayRecipe.title)
        .overlay(alignment: .bottom) {
            if let full = fullRecipe, let ingredients = full.ingredients, !ingredients.isEmpty {
                addAllButton(ingredients: ingredients)
            }
        }
        .overlay(alignment: .top) {
            if showAddedBanner {
                addedBanner
            }
        }
        .task {
            await loadDetail()
        }
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        AsyncImage(url: displayRecipe.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 240)
                    .clipped()
            case .failure, .empty:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 240)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(.systemGray3))
                    )
            @unknown default:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 240)
            }
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text(displayRecipe.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // Time & servings row
            if displayRecipe.readyInMinutes > 0 || displayRecipe.servings > 0 {
                metaRow
            }

            // Macro bar
            if displayRecipe.calories > 0 {
                macroBar
                    .padding(.horizontal, 20)
            }

            Divider().padding(.horizontal, 20)

            // Ingredients
            ingredientsSection

            // Bottom padding for add-all button
            Color.clear.frame(height: 80)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 20) {
            if displayRecipe.readyInMinutes > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.green)
                    Text("\(displayRecipe.readyInMinutes) min")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            if displayRecipe.servings > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.green)
                    Text("\(displayRecipe.servings) servings")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .foregroundStyle(.secondary)
    }

    private var macroBar: some View {
        HStack(spacing: 8) {
            macroPill(label: "Calories", value: displayRecipe.calories, unit: "kcal", color: .orange)
            macroPill(label: "Protein", value: displayRecipe.protein, unit: "g", color: .green)
            macroPill(label: "Carbs", value: displayRecipe.carbs, unit: "g", color: .blue)
            macroPill(label: "Fat", value: displayRecipe.fat, unit: "g", color: .red)
        }
    }

    private func macroPill(label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(value))\(unit == "kcal" ? "" : "g")")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Ingredients Section

    @ViewBuilder
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)

            if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading ingredients…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if let ingredients = fullRecipe?.ingredients, !ingredients.isEmpty {
                VStack(spacing: 0) {
                    ForEach(ingredients) { ingredient in
                        RecipeIngredientRow(
                            ingredient: ingredient,
                            isAdded: addedIDs.contains(ingredient.id),
                            onAdd: { addIngredient(ingredient) }
                        )
                        .padding(.horizontal, 20)

                        if ingredient.id != ingredients.last?.id {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
            } else {
                Text("Ingredient details unavailable.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Add All Button

    private func addAllButton(ingredients: [RecipeIngredient]) -> some View {
        let allAdded = ingredients.allSatisfy { addedIDs.contains($0.id) }
        return Button {
            addAllIngredients(ingredients)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: allAdded ? "checkmark.circle.fill" : "cart.badge.plus")
                Text(allAdded ? "All Added to Grocery List" : "Add All to Grocery List")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(allAdded ? Color.secondary : Color.green)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .disabled(allAdded)
        .animation(.easeInOut(duration: 0.2), value: allAdded)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .frame(height: 100)
        )
    }

    // MARK: - Added Banner

    private var addedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Added to Grocery List")
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Actions

    private func loadDetail() async {
        do {
            let detail = try await SpoonacularService.shared.fetchRecipeDetail(id: recipe.id)
            await MainActor.run {
                fullRecipe = detail
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func addIngredient(_ ingredient: RecipeIngredient) {
        let item = GroceryItem(customName: ingredient.original)
        modelContext.insert(item)
        try? modelContext.save()
        addedIDs.insert(ingredient.id)
        showBanner()
    }

    private func addAllIngredients(_ ingredients: [RecipeIngredient]) {
        for ingredient in ingredients {
            guard !addedIDs.contains(ingredient.id) else { continue }
            let item = GroceryItem(customName: ingredient.original)
            modelContext.insert(item)
            addedIDs.insert(ingredient.id)
        }
        try? modelContext.save()
        showBanner()
    }

    private func showBanner() {
        withAnimation {
            showAddedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showAddedBanner = false
            }
        }
    }
}
