import Foundation
import SwiftData

/// API client for Open Food Facts with local caching
final class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private let baseURL = "https://world.openfoodfacts.org/api/v2/product"
    private let session: URLSession

    private let requestedFields = [
        "product_name", "brands", "image_front_url",
        "nutriments", "nutrition_grades", "nova_group",
        "ingredients_text", "allergens", "additives_tags",
        "categories", "quantity", "nutriscore_score"
    ].joined(separator: ",")

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Cache-Aware Fetch (Primary API)

    /// Fetch product with cache support: API-first, cache fallback.
    /// - On success: updates the cache and returns the fresh product.
    /// - On network failure: returns the cached version if available.
    /// - If neither works: throws the original error.
    func fetchProduct(barcode: String, modelContext: ModelContext) async throws -> Product {
        do {
            // Try API first
            let product = try await fetchFromAPI(barcode: barcode)

            // Cache the result
            await MainActor.run {
                cacheProduct(product, in: modelContext)
            }

            return product

        } catch {
            // API failed → try cache
            let cached: CachedProduct? = await MainActor.run {
                let descriptor = FetchDescriptor<CachedProduct>(
                    predicate: #Predicate { $0.barcode == barcode }
                )
                return try? modelContext.fetch(descriptor).first
            }

            if let cached = cached {
                return cached.toProduct()
            }

            // Neither API nor cache → rethrow
            throw error
        }
    }

    // MARK: - Direct API Fetch (No Cache)

    /// Fetch product directly from the API without cache interaction.
    func fetchProduct(barcode: String) async throws -> Product {
        try await fetchFromAPI(barcode: barcode)
    }

    // MARK: - Private

    private func fetchFromAPI(barcode: String) async throws -> Product {
        let urlString = "\(baseURL)/\(barcode).json?fields=\(requestedFields)"
        guard let url = URL(string: urlString) else {
            throw ShelfScoreError.invalidBarcode
        }

        var request = URLRequest(url: url)
        request.setValue(
            "ShelfScore iOS/1.0 (kunalsarna; contact@shelfscore.app)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShelfScoreError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 404:
            throw ShelfScoreError.productNotFound
        case 429:
            throw ShelfScoreError.rateLimited
        default:
            throw ShelfScoreError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let offResponse = try decoder.decode(OFFResponse.self, from: data)

        guard offResponse.status == 1, let product = Product.from(offResponse: offResponse) else {
            throw ShelfScoreError.productNotFound
        }

        return product
    }

    /// Save or update cached product data
    private func cacheProduct(_ product: Product, in modelContext: ModelContext) {
        let barcode = product.id
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate { $0.barcode == barcode }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: product)
        } else {
            let cached = CachedProduct(from: product)
            modelContext.insert(cached)
        }

        try? modelContext.save()
    }
}

// MARK: - Errors
enum ShelfScoreError: LocalizedError {
    case invalidBarcode
    case productNotFound
    case networkError(String)
    case rateLimited
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "Invalid barcode format"
        case .productNotFound:
            return "Product not found"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .rateLimited:
            return "Too many requests. Please try again shortly."
        case .cameraUnavailable:
            return "Camera is not available"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .productNotFound:
            return "This product isn't in the Open Food Facts database yet. Try scanning a different product."
        case .networkError:
            return "Check your internet connection and try again."
        case .rateLimited:
            return "Please wait a moment before scanning another product."
        case .cameraUnavailable:
            return "Please enable camera access in Settings."
        case .invalidBarcode:
            return "Make sure the barcode is clearly visible."
        }
    }
}
