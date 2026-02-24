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
            let cached: Product? = await MainActor.run {
                let descriptor = FetchDescriptor<CachedProduct>(
                    predicate: #Predicate { $0.barcode == barcode }
                )
                return try? modelContext.fetch(descriptor).first?.toProduct()
            }

            if let cached = cached {
                return cached
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

    // MARK: - Product Search

    /// Search for products by name globally.
    func searchProducts(query: String, limit: Int = 20) async -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/search")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "page_size", value: "\(limit)"),
            URLQueryItem(name: "fields", value: "code,\(requestedFields)")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(
            "ShelfScore iOS/1.0 (kunalsarna; contact@shelfscore.app)",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
            return (decoded.products ?? []).compactMap { offProduct -> Product? in
                guard offProduct.productName?.isEmpty == false || offProduct.brands?.isEmpty == false else { return nil }
                return Product.from(offResponse: OFFResponse(
                    code: offProduct.code,
                    product: offProduct,
                    status: 1,
                    statusVerbose: "product found"
                ))
            }
        } catch {
            return []
        }
    }

    // MARK: - Search Alternatives

    /// Search for healthier products in the same category.
    /// Returns up to `limit` products that score higher than the given product.
    func searchAlternatives(for product: Product, limit: Int = 5) async -> [Product] {
        guard let categories = product.categories, !categories.isEmpty else {
            return []
        }

        // Prefer the first (most general) category for broader search results
        let categoryList = categories.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let primaryCategory = categoryList.first, !primaryCategory.isEmpty else {
            return []
        }

        if product.healthScore.grade == .a { return [] } // Already the best

        // Build search URL using URLComponents for correct percent-encoding
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/search")!
        components.queryItems = [
            URLQueryItem(name: "categories_tags", value: primaryCategory),
            URLQueryItem(name: "countries_tags", value: "en:united-states"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "code,\(requestedFields)")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(
            "ShelfScore iOS/1.0 (kunalsarna; contact@shelfscore.app)",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(OFFSearchResponse.self, from: data)

            guard let offProducts = searchResponse.products else { return [] }

            // Convert to domain products, filter to better scores, limit results
            let alternatives = offProducts.compactMap { offProduct -> Product? in
                // Build a minimal OFFResponse to reuse the existing converter
                let fakeResponse = OFFResponse(
                    code: offProduct.code,
                    product: offProduct,
                    status: 1,
                    statusVerbose: "product found"
                )
                return Product.from(offResponse: fakeResponse)
            }
            .filter { $0.id != product.id } // Exclude the original product
            .filter { $0.healthScore.score > product.healthScore.score } // Must be better
            .sorted { $0.healthScore.score > $1.healthScore.score } // Best first
            .prefix(limit)

            return Array(alternatives)
        } catch {
            return [] // Silently fail — alternatives are non-critical
        }
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
