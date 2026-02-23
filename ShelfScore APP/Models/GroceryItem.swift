import Foundation
import SwiftData

@Model
final class GroceryItem {
    var barcode: String
    var name: String
    var brand: String
    var imageURLString: String?
    var healthScore: Int
    var isBought: Bool
    var addedAt: Date
    var isCustom: Bool = false

    var imageURL: URL? { imageURLString.flatMap { URL(string: $0) } }

    /// Create from a scanned/searched product
    init(from product: Product) {
        self.barcode = product.id
        self.name = product.displayName
        self.brand = product.brand
        self.imageURLString = product.imageURL?.absoluteString
        self.healthScore = product.healthScore.score
        self.isBought = false
        self.addedAt = .now
        self.isCustom = false
    }

    /// Create a custom item with just a name (no product data)
    init(customName: String) {
        self.barcode = UUID().uuidString
        self.name = customName
        self.brand = ""
        self.imageURLString = nil
        self.healthScore = 0
        self.isBought = false
        self.addedAt = .now
        self.isCustom = true
    }
}
