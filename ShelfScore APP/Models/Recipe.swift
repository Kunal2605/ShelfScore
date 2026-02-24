import Foundation

// MARK: - App Domain Models

struct Recipe: Identifiable {
    let id: Int
    let title: String
    let imageURL: URL?
    let servings: Int
    let readyInMinutes: Int
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    var ingredients: [RecipeIngredient]?
}

struct RecipeIngredient: Identifiable {
    let id: Int
    let name: String
    let original: String    // e.g. "2 cups all-purpose flour"
    let imageURL: URL?
}

// MARK: - Spoonacular API Response Models

struct SpoonacularSearchResponse: Codable {
    let results: [SpoonacularRecipeSummary]
    let totalResults: Int
}

struct SpoonacularRecipeSummary: Codable {
    let id: Int
    let title: String
    let image: String?
    let nutrition: SpoonacularNutritionSummary?
}

struct SpoonacularNutritionSummary: Codable {
    let nutrients: [SpoonacularNutrient]
}

struct SpoonacularNutrient: Codable {
    let name: String
    let amount: Double
    let unit: String
}

struct SpoonacularRecipeDetail: Codable {
    let id: Int
    let title: String
    let image: String?
    let servings: Int
    let readyInMinutes: Int
    let extendedIngredients: [SpoonacularIngredient]
    let nutrition: SpoonacularNutritionSummary?
}

struct SpoonacularIngredient: Codable {
    let id: Int
    let name: String
    let original: String
    let amount: Double
    let unit: String
    let image: String?
}

// MARK: - Convenience Mappers

extension SpoonacularNutritionSummary {
    func amount(for nutrientName: String) -> Double {
        nutrients.first { $0.name.lowercased() == nutrientName.lowercased() }?.amount ?? 0
    }
}

extension SpoonacularRecipeSummary {
    func toRecipe() -> Recipe {
        let imageURL = image.flatMap { URL(string: $0) }
        return Recipe(
            id: id,
            title: title,
            imageURL: imageURL,
            servings: 0,
            readyInMinutes: 0,
            calories: nutrition?.amount(for: "Calories") ?? 0,
            protein: nutrition?.amount(for: "Protein") ?? 0,
            carbs: nutrition?.amount(for: "Carbohydrates") ?? 0,
            fat: nutrition?.amount(for: "Fat") ?? 0,
            fiber: nutrition?.amount(for: "Fiber") ?? 0,
            ingredients: nil
        )
    }
}

extension SpoonacularRecipeDetail {
    func toRecipe() -> Recipe {
        let imageURL = image.flatMap { URL(string: $0) }
        let ingredients = extendedIngredients.map { ing in
            let ingImageURL: URL? = ing.image.flatMap {
                URL(string: "https://spoonacular.com/cdn/ingredients_100x100/\($0)")
            }
            return RecipeIngredient(
                id: ing.id,
                name: ing.name,
                original: ing.original,
                imageURL: ingImageURL
            )
        }
        return Recipe(
            id: id,
            title: title,
            imageURL: imageURL,
            servings: servings,
            readyInMinutes: readyInMinutes,
            calories: nutrition?.amount(for: "Calories") ?? 0,
            protein: nutrition?.amount(for: "Protein") ?? 0,
            carbs: nutrition?.amount(for: "Carbohydrates") ?? 0,
            fat: nutrition?.amount(for: "Fat") ?? 0,
            fiber: nutrition?.amount(for: "Fiber") ?? 0,
            ingredients: ingredients
        )
    }
}
