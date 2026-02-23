import SwiftUI
import SwiftData

struct GrocerySearchSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Product] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var addedIDs: Set<String> = []
    @State private var quickAdded: Set<String> = []

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .background(Color.white)

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        if !trimmedQuery.isEmpty {
                            quickAddRow(name: trimmedQuery)
                        }

                        if isSearching {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Searching…")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)

                        } else if !results.isEmpty {
                            productResultsList

                        } else if hasSearched {
                            noResultsView

                        } else if trimmedQuery.isEmpty {
                            promptView
                        }
                    }
                    .padding(.bottom, 32)
                }
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add to Grocery List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search or type an item…", text: $query)
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
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Quick Add Row

    private func quickAddRow(name: String) -> some View {
        let isAdded = quickAdded.contains(name.lowercased())
        return Button {
            guard !isAdded else { return }
            addCustomItem(name: name)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Add")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(isAdded ? Color.green : Color.green.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }

    // MARK: - Product Results List

    private var productResultsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(results) { product in
                productRow(product)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func productRow(_ product: Product) -> some View {
        let isAdded = addedIDs.contains(product.id)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                SearchResultRow(product: product)
                Spacer(minLength: 8)
                Button {
                    addToGroceryList(product)
                } label: {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(isAdded ? Color.green : Color.green.opacity(0.75))
                }
                .buttonStyle(.plain)
                .disabled(isAdded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            if product.id != results.last?.id {
                Divider().padding(.leading, 80)
            }
        }
    }

    // MARK: - Empty States

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No products found")
                .foregroundStyle(.secondary)
            Text("Use Quick Add above to add it manually.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
    }

    private var promptView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.green.opacity(0.4))
            Text("Search for a product or type\nan item name to add it directly")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 48)
    }

    // MARK: - Actions

    private func performSearch() {
        guard !trimmedQuery.isEmpty else { return }
        isSearching = true
        hasSearched = true
        results = []

        Task {
            let found = await OpenFoodFactsService.shared.searchProducts(query: trimmedQuery)
            await MainActor.run {
                results = found
                isSearching = false
            }
        }
    }

    private func addToGroceryList(_ product: Product) {
        let item = GroceryItem(from: product)
        modelContext.insert(item)
        try? modelContext.save()
        addedIDs.insert(product.id)
    }

    private func addCustomItem(name: String) {
        let item = GroceryItem(customName: name)
        modelContext.insert(item)
        try? modelContext.save()
        quickAdded.insert(name.lowercased())
    }
}
