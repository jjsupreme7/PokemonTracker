import SwiftUI
import SwiftData
import Charts

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CollectionCard.dateAdded, order: .reverse) private var collection: [CollectionCard]

    @State private var sortOption: SortOption = .dateAdded
    @State private var showingDeleteAlert = false
    @State private var cardToDelete: CollectionCard?

    private var totalValue: Double {
        collection.reduce(0) { $0 + $1.totalValue }
    }

    private var totalCost: Double {
        collection.reduce(0) { $0 + ($1.totalCost ?? 0) }
    }

    private var totalCards: Int {
        collection.reduce(0) { $0 + $1.quantity }
    }

    private var profitLoss: Double {
        totalValue - totalCost
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Portfolio Value Card
                    portfolioValueCard

                    // Stats Grid
                    statsGrid

                    // Sort Options
                    sortPicker

                    // Collection List
                    if collection.isEmpty {
                        emptyStateView
                    } else {
                        collectionList
                    }
                }
                .padding()
            }
            .background(Color.pokemon.background)
            .navigationTitle("Portfolio")
            .preferredColorScheme(.dark)
            .alert("Delete Card", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let card = cardToDelete {
                        deleteCard(card)
                    }
                }
            } message: {
                Text("Are you sure you want to remove this card from your collection?")
            }
        }
    }

    // MARK: - Portfolio Value Card

    private var portfolioValueCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Total Collection Value")
                    .font(.subheadline)
                    .foregroundColor(Color.pokemon.textSecondary)

                Text(String(format: "$%.2f", totalValue))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(Color.pokemon.textPrimary)
            }

            if totalCost > 0 {
                HStack(spacing: 8) {
                    let isPositive = profitLoss >= 0
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%@$%.2f", isPositive ? "+" : "", profitLoss))

                    if totalCost > 0 {
                        let percentage = (profitLoss / totalCost) * 100
                        Text(String(format: "(%@%.1f%%)", isPositive ? "+" : "", percentage))
                    }
                }
                .font(.headline)
                .foregroundColor(profitLoss >= 0 ? Color.pokemon.positive : Color.pokemon.negative)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.pokemon.primary.opacity(0.2), Color.pokemon.gold.opacity(0.1), Color.pokemon.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Total Cards",
                value: "\(totalCards)",
                icon: "square.stack.fill",
                color: Color.pokemon.gold
            )

            StatCard(
                title: "Unique",
                value: "\(collection.count)",
                icon: "sparkles",
                color: Color.pokemon.primary
            )

            StatCard(
                title: "Cost Basis",
                value: String(format: "$%.0f", totalCost),
                icon: "dollarsign.circle.fill",
                color: Color.pokemon.gold
            )
        }
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        HStack {
            Text("Sort by")
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)

            Picker("Sort", selection: $sortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.pokemon.primary)

            Spacer()
        }
    }

    // MARK: - Collection List

    private var collectionList: some View {
        LazyVStack(spacing: 12) {
            ForEach(sortedCollection, id: \.cardId) { card in
                PortfolioCardRow(card: card)
                    .contextMenu {
                        Button(role: .destructive) {
                            cardToDelete = card
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(Color.pokemon.gold)

            Text("No Cards Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.pokemon.textPrimary)

            Text("Scan or search for cards to add them to your collection.")
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Sorted Collection

    private var sortedCollection: [CollectionCard] {
        switch sortOption {
        case .dateAdded:
            return collection.sorted { $0.dateAdded > $1.dateAdded }
        case .name:
            return collection.sorted { $0.name < $1.name }
        case .value:
            return collection.sorted { $0.totalValue > $1.totalValue }
        case .priceChange:
            return collection.sorted {
                ($0.profitLossPercent ?? 0) > ($1.profitLossPercent ?? 0)
            }
        }
    }

    // MARK: - Delete Card

    private func deleteCard(_ card: CollectionCard) {
        let cardId = card.cardId
        modelContext.delete(card)
        try? modelContext.save()

        // Also delete from Supabase
        Task {
            try? await APIService.shared.deleteCard(cardId: cardId)
        }
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case name = "Name"
    case value = "Value"
    case priceChange = "% Change"
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(Color.pokemon.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.pokemon.surface)
        .cornerRadius(12)
    }
}

// MARK: - Portfolio Card Row

struct PortfolioCardRow: View {
    let card: CollectionCard

    var body: some View {
        HStack(spacing: 12) {
            // Card Image
            AsyncImage(url: URL(string: card.imageSmall)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.pokemon.background)
            }
            .frame(width: 50, height: 70)
            .cornerRadius(6)

            // Card Info
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)

                Text(card.setName)
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)

                HStack {
                    Text("×\(card.quantity)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pokemon.gold.opacity(0.2))
                        .foregroundColor(Color.pokemon.gold)
                        .cornerRadius(4)

                    if let rarity = card.rarity {
                        Text(rarity)
                            .font(.caption)
                            .foregroundColor(Color.pokemon.textSecondary)
                    }
                }
            }

            Spacer()

            // Value & Change
            VStack(alignment: .trailing, spacing: 4) {
                Text(card.formattedTotalValue)
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)

                if let change = card.formattedProfitLossPercent {
                    let isPositive = (card.profitLossPercent ?? 0) >= 0
                    HStack(spacing: 2) {
                        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text(change)
                            .font(.caption)
                    }
                    .foregroundColor(isPositive ? Color.pokemon.positive : Color.pokemon.negative)
                } else {
                    Text(card.formattedPrice)
                        .font(.caption)
                        .foregroundColor(Color.pokemon.textSecondary)
                }
            }
        }
        .padding()
        .background(Color.pokemon.surface)
        .cornerRadius(12)
    }
}

#Preview {
    PortfolioView()
        .modelContainer(for: CollectionCard.self, inMemory: true)
}
