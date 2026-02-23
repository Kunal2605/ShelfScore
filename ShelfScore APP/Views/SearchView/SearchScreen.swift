import SwiftUI

struct SearchScreen: View {
    @State private var query = ""
    @State private var results: [Product] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var selectedProduct: Product?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)

                Divider()

                // Content
                ZStack {
                    Color(.systemGroupedBackground).ignoresSafeArea()

                    if isSearching {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Searching…")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    } else if results.isEmpty && hasSearched {
                        noResultsView

                    } else if results.isEmpty {
                        promptView

                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            TextField("Search products, brands…", text: $query)
                .font(.system(size: 16))
                .submitLabel(.search)
                .onSubmit { performSearch() }
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    hasSearched = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 16))
                }
            }

            if !query.isEmpty {
                Button("Search") { performSearch() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(results) { product in
                    Button { selectedProduct = product } label: {
                        SearchResultRow(product: product)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)

                    if product.id != results.last?.id {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Empty States

    private var promptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.green.opacity(0.4))

            VStack(spacing: 6) {
                Text("Search for a Product")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Type a product name or brand\nand tap Search")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 6) {
                Text("No Results Found")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Try a different name or brand")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Action

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        hasSearched = true
        results = []

        Task {
            let found = await OpenFoodFactsService.shared.searchProducts(query: query)
            await MainActor.run {
                results = found
                isSearching = false
            }
        }
    }
}
