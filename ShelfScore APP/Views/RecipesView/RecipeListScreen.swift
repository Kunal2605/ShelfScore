import SwiftUI

struct RecipeListScreen: View {
    @State private var query = ""
    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var hasSearched = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGroupedBackground))

                if isLoading {
                    loadingView
                } else if recipes.isEmpty && hasSearched {
                    noResultsView
                } else {
                    recipeGrid
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recipes")
        }
        .task {
            await loadPopular()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search recipes…", text: $query)
                .font(.system(size: 16))
                .submitLabel(.search)
                .onSubmit { performSearch() }
            if !query.isEmpty {
                Button {
                    query = ""
                    hasSearched = false
                    Task { await loadPopular() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Recipe Grid

    private var recipeGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !recipes.isEmpty {
                    Text(hasSearched ? "Results for \"\(query)\"" : "Popular Recipes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(recipes) { recipe in
                            NavigationLink(destination: RecipeDetailScreen(recipe: recipe)) {
                                RecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Finding recipes…")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "fork.knife")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.green.opacity(0.4))
            }
            VStack(spacing: 6) {
                Text("No Recipes Found")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Try a different search term")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        hasSearched = true
        recipes = []
        Task {
            let results = await SpoonacularService.shared.searchRecipes(query: query.trimmingCharacters(in: .whitespaces))
            await MainActor.run {
                recipes = results
                isLoading = false
            }
        }
    }

    private func loadPopular() async {
        guard recipes.isEmpty else { return }
        await MainActor.run { isLoading = true }
        let results = await SpoonacularService.shared.fetchPopularRecipes()
        await MainActor.run {
            recipes = results
            isLoading = false
        }
    }
}
