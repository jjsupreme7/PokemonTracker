import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [Card] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Results or Empty State
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if searchResults.isEmpty && hasSearched {
                    noResultsView
                } else if searchResults.isEmpty {
                    emptyStateView
                } else {
                    searchResultsList
                }
            }
            .background(Color.pokemon.background)
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search cards by name...")
            .onSubmit(of: .search) {
                Task {
                    await performSearch()
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchResults) { card in
                    NavigationLink(destination: CardDetailView(card: card)) {
                        SearchResultRow(card: card)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.pokemon.primary)
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.pokemon.negative)

            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await performSearch()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.pokemon.primary)        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color.pokemon.textSecondary)

            Text("No Results")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            Text("No cards found for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color.pokemon.gold)

            Text("Search Pokemon Cards")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            Text("Search by card name to find pricing and details")
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)
                .multilineTextAlignment(.center)

            // Suggested Searches
            VStack(alignment: .leading, spacing: 8) {
                Text("Try searching for:")
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)

                HStack(spacing: 8) {
                    SuggestedSearchChip(text: "Charizard") {
                        searchText = "Charizard"
                        Task { await performSearch() }
                    }
                    SuggestedSearchChip(text: "Pikachu") {
                        searchText = "Pikachu"
                        Task { await performSearch() }
                    }
                    SuggestedSearchChip(text: "Mewtwo") {
                        searchText = "Mewtwo"
                        Task { await performSearch() }
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search Logic

    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isLoading = true
        errorMessage = nil
        hasSearched = true

        do {
            let results = try await PokemonTCGService.shared.searchCards(name: searchText)
            await MainActor.run {
                searchResults = results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let card: Card

    var body: some View {
        HStack(spacing: 12) {
            // Card Image
            AsyncImage(url: URL(string: card.images.small)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.pokemon.surface)
            }
            .frame(width: 60, height: 84)
            .cornerRadius(6)

            // Card Info
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)

                Text(card.set.name)
                    .font(.subheadline)
                    .foregroundColor(Color.pokemon.textSecondary)

                HStack {
                    if let rarity = card.rarity {
                        Text(rarity)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.pokemon.primary.opacity(0.2))
                            .foregroundColor(Color.pokemon.gold)
                            .cornerRadius(4)
                    }

                    Text(card.setIdentifier)
                        .font(.caption)
                        .foregroundColor(Color.pokemon.textSecondary)
                }
            }

            Spacer()

            // Price
            VStack(alignment: .trailing, spacing: 4) {
                Text(card.formattedPrice)
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)
            }
        }
        .padding()
        .background(Color.pokemon.surface)
        .cornerRadius(12)
    }
}

// MARK: - Suggested Search Chip

struct SuggestedSearchChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.pokemon.surface)
                .foregroundColor(Color.pokemon.textPrimary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.pokemon.primary.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

#Preview {
    SearchView()
}
