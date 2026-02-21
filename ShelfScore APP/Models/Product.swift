import Foundation

// MARK: - Open Food Facts API Response
struct OFFResponse: Codable {
    let code: String?
    let product: OFFProduct?
    let status: Int?
    let statusVerbose: String?

    enum CodingKeys: String, CodingKey {
        case code, product, status
        case statusVerbose = "status_verbose"
    }
}

struct OFFProduct: Codable {
    let productName: String?
    let brands: String?
    let imageFrontURL: String?
    let nutriments: OFFNutriments?
    let nutritionGrades: String?
    let novaGroup: Int?
    let ingredientsText: String?
    let allergens: String?
    let additivesTags: [String]?
    let categories: String?
    let quantity: String?
    let nutriscoreScore: Int?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case imageFrontURL = "image_front_url"
        case nutriments
        case nutritionGrades = "nutrition_grades"
        case novaGroup = "nova_group"
        case ingredientsText = "ingredients_text"
        case allergens
        case additivesTags = "additives_tags"
        case categories
        case quantity
        case nutriscoreScore = "nutriscore_score"
    }
}

struct OFFNutriments: Codable {
    let energyKcal100g: Double?
    let fat100g: Double?
    let saturatedFat100g: Double?
    let sugars100g: Double?
    let salt100g: Double?
    let fiber100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let sodium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case sugars100g = "sugars_100g"
        case salt100g = "salt_100g"
        case fiber100g = "fiber_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sodium100g = "sodium_100g"
    }
}

// MARK: - App Domain Model
struct Product: Identifiable {
    let id: String // barcode
    let name: String
    let brand: String
    let imageURL: URL?
    let nutrition: NutritionFacts
    let nutriscoreGrade: String? // a, b, c, d, e
    let novaGroup: Int? // 1-4
    let ingredients: String?
    let allergens: [String]
    let additives: [String]
    let categories: String?
    let quantity: String?
    let healthScore: HealthScore

    var displayName: String {
        if name.isEmpty && brand.isEmpty {
            return "Unknown Product"
        }
        return name.isEmpty ? brand : name
    }
}

extension Product {
    /// Create Product from Open Food Facts response
    static func from(offResponse: OFFResponse) -> Product? {
        guard let offProduct = offResponse.product else { return nil }

        let barcode = offResponse.code ?? "unknown"

        let nutrition = NutritionFacts(
            calories: offProduct.nutriments?.energyKcal100g ?? 0,
            fat: offProduct.nutriments?.fat100g ?? 0,
            saturatedFat: offProduct.nutriments?.saturatedFat100g ?? 0,
            carbohydrates: offProduct.nutriments?.carbohydrates100g ?? 0,
            sugars: offProduct.nutriments?.sugars100g ?? 0,
            fiber: offProduct.nutriments?.fiber100g ?? 0,
            proteins: offProduct.nutriments?.proteins100g ?? 0,
            salt: offProduct.nutriments?.salt100g ?? 0,
            sodium: offProduct.nutriments?.sodium100g ?? 0
        )

        let allergenList = offProduct.allergens?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty } ?? []

        let additiveList = offProduct.additivesTags?
            .map { $0.replacingOccurrences(of: "en:", with: "").replacingOccurrences(of: "-", with: " ").capitalized }
            ?? []

        let imageURL: URL? = {
            guard let urlString = offProduct.imageFrontURL else { return nil }
            return URL(string: urlString)
        }()

        let healthScore = HealthScoreCalculator.calculate(
            nutrition: nutrition,
            novaGroup: offProduct.novaGroup,
            additives: additiveList,
            nutriscoreGrade: offProduct.nutritionGrades
        )

        return Product(
            id: barcode,
            name: offProduct.productName ?? "",
            brand: offProduct.brands ?? "",
            imageURL: imageURL,
            nutrition: nutrition,
            nutriscoreGrade: offProduct.nutritionGrades,
            novaGroup: offProduct.novaGroup,
            ingredients: offProduct.ingredientsText,
            allergens: allergenList,
            additives: additiveList,
            categories: offProduct.categories,
            quantity: offProduct.quantity,
            healthScore: healthScore
        )
    }
}
