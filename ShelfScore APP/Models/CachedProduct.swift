import Foundation
import SwiftData

/// Full product cache for offline access via SwiftData.
/// Stores all nutrition data so previously scanned products
/// can be viewed without an internet connection.
@Model
final class CachedProduct {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String
    var imageURLString: String?

    // Nutrition (per 100g)
    var calories: Double
    var fat: Double
    var saturatedFat: Double
    var carbohydrates: Double
    var sugars: Double
    var fiber: Double
    var proteins: Double
    var salt: Double
    var sodium: Double

    // Metadata
    var nutriscoreGrade: String?
    var novaGroup: Int?
    var ingredients: String?
    var allergensJSON: String   // JSON-encoded [String]
    var additivesJSON: String   // JSON-encoded [String]
    var categories: String?
    var quantity: String?

    var cachedAt: Date

    init(
        barcode: String,
        name: String,
        brand: String,
        imageURLString: String? = nil,
        calories: Double = 0,
        fat: Double = 0,
        saturatedFat: Double = 0,
        carbohydrates: Double = 0,
        sugars: Double = 0,
        fiber: Double = 0,
        proteins: Double = 0,
        salt: Double = 0,
        sodium: Double = 0,
        nutriscoreGrade: String? = nil,
        novaGroup: Int? = nil,
        ingredients: String? = nil,
        allergensJSON: String = "[]",
        additivesJSON: String = "[]",
        categories: String? = nil,
        quantity: String? = nil,
        cachedAt: Date = .now
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.imageURLString = imageURLString
        self.calories = calories
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.carbohydrates = carbohydrates
        self.sugars = sugars
        self.fiber = fiber
        self.proteins = proteins
        self.salt = salt
        self.sodium = sodium
        self.nutriscoreGrade = nutriscoreGrade
        self.novaGroup = novaGroup
        self.ingredients = ingredients
        self.allergensJSON = allergensJSON
        self.additivesJSON = additivesJSON
        self.categories = categories
        self.quantity = quantity
        self.cachedAt = cachedAt
    }

    // MARK: - Conversion

    /// Create a CachedProduct from a domain Product
    convenience init(from product: Product) {
        let allergens = (try? JSONEncoder().encode(product.allergens)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let additives = (try? JSONEncoder().encode(product.additives)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        self.init(
            barcode: product.id,
            name: product.name,
            brand: product.brand,
            imageURLString: product.imageURL?.absoluteString,
            calories: product.nutrition.calories,
            fat: product.nutrition.fat,
            saturatedFat: product.nutrition.saturatedFat,
            carbohydrates: product.nutrition.carbohydrates,
            sugars: product.nutrition.sugars,
            fiber: product.nutrition.fiber,
            proteins: product.nutrition.proteins,
            salt: product.nutrition.salt,
            sodium: product.nutrition.sodium,
            nutriscoreGrade: product.nutriscoreGrade,
            novaGroup: product.novaGroup,
            ingredients: product.ingredients,
            allergensJSON: allergens,
            additivesJSON: additives,
            categories: product.categories,
            quantity: product.quantity
        )
    }

    /// Convert cached data back to a domain Product
    func toProduct() -> Product {
        let nutrition = NutritionFacts(
            calories: calories,
            fat: fat,
            saturatedFat: saturatedFat,
            carbohydrates: carbohydrates,
            sugars: sugars,
            fiber: fiber,
            proteins: proteins,
            salt: salt,
            sodium: sodium
        )

        let allergens: [String] = {
            guard let data = allergensJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return arr
        }()

        let additives: [String] = {
            guard let data = additivesJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return arr
        }()

        let imageURL: URL? = imageURLString.flatMap { URL(string: $0) }

        let healthScore = HealthScoreCalculator.calculate(
            nutrition: nutrition,
            novaGroup: novaGroup,
            additives: additives,
            nutriscoreGrade: nutriscoreGrade
        )

        return Product(
            id: barcode,
            name: name,
            brand: brand,
            imageURL: imageURL,
            nutrition: nutrition,
            nutriscoreGrade: nutriscoreGrade,
            novaGroup: novaGroup,
            ingredients: ingredients,
            allergens: allergens,
            additives: additives,
            categories: categories,
            quantity: quantity,
            healthScore: healthScore
        )
    }

    /// Update this cached product with fresh data from a Product
    func update(from product: Product) {
        name = product.name
        brand = product.brand
        imageURLString = product.imageURL?.absoluteString
        calories = product.nutrition.calories
        fat = product.nutrition.fat
        saturatedFat = product.nutrition.saturatedFat
        carbohydrates = product.nutrition.carbohydrates
        sugars = product.nutrition.sugars
        fiber = product.nutrition.fiber
        proteins = product.nutrition.proteins
        salt = product.nutrition.salt
        sodium = product.nutrition.sodium
        nutriscoreGrade = product.nutriscoreGrade
        novaGroup = product.novaGroup
        ingredients = product.ingredients
        allergensJSON = (try? JSONEncoder().encode(product.allergens)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        additivesJSON = (try? JSONEncoder().encode(product.additives)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        categories = product.categories
        quantity = product.quantity
        cachedAt = .now
    }
}
