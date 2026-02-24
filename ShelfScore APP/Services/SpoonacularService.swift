import Foundation

final class SpoonacularService {
    static let shared = SpoonacularService()

    private let apiKey = Secrets.spoonacularAPIKey
    private let base = "https://api.spoonacular.com"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Search Recipes

    func searchRecipes(query: String, number: Int = 20) async -> [Recipe] {
        var components = URLComponents(string: "\(base)/recipes/complexSearch")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "addRecipeNutrition", value: "true"),
            URLQueryItem(name: "number", value: "\(number)"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        return await fetch(components: components)
    }

    // MARK: - Popular Recipes (default browse)

    func fetchPopularRecipes(number: Int = 20) async -> [Recipe] {
        var components = URLComponents(string: "\(base)/recipes/complexSearch")!
        components.queryItems = [
            URLQueryItem(name: "sort", value: "popularity"),
            URLQueryItem(name: "addRecipeNutrition", value: "true"),
            URLQueryItem(name: "number", value: "\(number)"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        return await fetch(components: components)
    }

    // MARK: - Recipe Detail (with full ingredients)

    func fetchRecipeDetail(id: Int) async throws -> Recipe {
        var components = URLComponents(string: "\(base)/recipes/\(id)/information")!
        components.queryItems = [
            URLQueryItem(name: "includeNutrition", value: "true"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let detail = try JSONDecoder().decode(SpoonacularRecipeDetail.self, from: data)
        return detail.toRecipe()
    }

    // MARK: - Private Helpers

    private func fetch(components: URLComponents) async -> [Recipe] {
        guard let url = components.url else { return [] }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(SpoonacularSearchResponse.self, from: data)
            return decoded.results.map { $0.toRecipe() }
        } catch {
            return []
        }
    }
}
