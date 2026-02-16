import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedTab: Int
    @Query private var collection: [CollectionCard]
    @State private var trendingCards: [Card] = []
    @State private var isLoading = false
    @State private var showScrollToTop = false
    @State private var scrollOffset: CGFloat = 0
    @State private var marketMovers: MarketMoversResponse?
    @State private var isLoadingMovers = false
    @State private var selectedMoverCategory: MoverCategory = .gainers
    @State private var selectedCard: Card?
    @State private var isLoadingCard = false

    enum MoverCategory: String, CaseIterable {
        case gainers = "Gainers"
        case losers = "Losers"
        case hot = "Hot"
    }

    private var totalValue: Double {
        collection.reduce(0) { $0 + $1.totalValue }
    }

    private var totalCards: Int {
        collection.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Anchor for scroll to top
                            Color.clear
                                .frame(height: 0)
                                .id("top")

                            // Portfolio Summary Card
                            portfolioSummaryCard

                            // Market Movers Carousel (horizontal)
                            marketMoversCarousel

                            // Quick Actions
                            quickActionsSection

                            // Trending Cards Carousel (horizontal)
                            if !trendingCards.isEmpty {
                                trendingCardsSection
                            }

                            // Recent Additions
                            if !collection.isEmpty {
                                recentAdditionsSection
                            }

                            // Empty State
                            if collection.isEmpty && trendingCards.isEmpty && !isLoading {
                                emptyStateView
                            }

                            // Loading indicator
                            if isLoading {
                                ProgressView()
                                    .tint(Color.pokemon.primary)
                                    .padding()
                            }

                            // Bottom padding for FAB
                            Color.clear.frame(height: 60)
                        }
                        .padding()
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geo.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showScrollToTop = value < -300
                        }
                    }
                    .refreshable {
                        await loadMarketMovers()
                        await loadTrendingCards()
                    }

                    // Scroll to top FAB
                    if showScrollToTop {
                        ScrollToTopButton {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("top", anchor: .top)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .background(Color.pokemon.background)
            .navigationTitle("Pokemon Tracker")
            .preferredColorScheme(.dark)
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card)
            }
            .overlay {
                if isLoadingCard {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(ProgressView().tint(Color.pokemon.primary))
                }
            }
            .task {
                await loadMarketMovers()
                await loadTrendingCards()
            }
        }
    }

    // MARK: - Load Market Movers

    private func loadMarketMovers() async {
        guard !isLoadingMovers else { return }
        isLoadingMovers = true

        do {
            let response = try await APIService.shared.getMarketMovers()
            await MainActor.run {
                marketMovers = response
                isLoadingMovers = false
            }
        } catch {
            await MainActor.run { isLoadingMovers = false }
            print("Failed to load market movers: \(error)")
        }
    }

    // MARK: - Load Trending Cards

    private func loadTrendingCards() async {
        // Don't reload if we already have cards or are loading
        guard trendingCards.isEmpty, !isLoading else { return }

        await MainActor.run { isLoading = true }

        do {
            // Search for popular Pokemon cards - use simple query
            // The API searches across all fields, so "charizard" finds Charizard cards
            let cards = try await PokemonTCGService.shared.searchCards(
                name: "charizard",
                pageSize: 10
            )

            // Check if task was cancelled
            try Task.checkCancellation()

            await MainActor.run {
                trendingCards = cards
                isLoading = false
            }
        } catch is CancellationError {
            // Task was cancelled, that's okay
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
            print("Failed to load trending cards: \(error)")
        }
    }

    // MARK: - Card Navigation

    private func loadMarketMoverCard(_ moverCard: MarketMoverCard) async {
        isLoadingCard = true
        do {
            let cards = try await PokemonTCGService.shared.searchCards(
                name: moverCard.name,
                pageSize: 5
            )
            let match = cards.first { $0.id == moverCard.cardId } ?? cards.first
            await MainActor.run {
                if let match = match { selectedCard = match }
                isLoadingCard = false
            }
        } catch {
            print("Failed to load market mover card: \(error)")
            await MainActor.run { isLoadingCard = false }
        }
    }

    private func loadRecentCard(_ collectionCard: CollectionCard) async {
        isLoadingCard = true
        do {
            let cards = try await PokemonTCGService.shared.searchCards(
                name: collectionCard.name,
                pageSize: 5
            )
            let match = cards.first { $0.number == collectionCard.number } ?? cards.first
            await MainActor.run {
                if let match = match { selectedCard = match }
                isLoadingCard = false
            }
        } catch {
            print("Failed to load recent card: \(error)")
            await MainActor.run { isLoadingCard = false }
        }
    }

    // MARK: - Portfolio Summary

    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolio Value")
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)

            Text(String(format: "$%.2f", totalValue))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color.pokemon.textPrimary)

            HStack {
                Label("\(totalCards) cards", systemImage: "square.stack.fill")
                Spacer()
                Label("\(collection.count) unique", systemImage: "sparkles")
            }
            .font(.caption)
            .foregroundColor(Color.pokemon.textSecondary)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.pokemon.primary.opacity(0.2), Color.pokemon.gold.opacity(0.1), Color.pokemon.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    // MARK: - Market Movers Carousel

    private var currentMoverCards: [MarketMoverCard] {
        guard let movers = marketMovers else { return [] }
        switch selectedMoverCategory {
        case .gainers: return movers.gainers
        case .losers: return movers.losers
        case .hot: return movers.hotCards
        }
    }

    private var marketMoversCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Market Movers")
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)

                Spacer()

                Button {
                    selectedTab = 1
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(Color.pokemon.primary)
                }
            }

            // Category Picker
            HStack(spacing: 8) {
                ForEach(MoverCategory.allCases, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMoverCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.caption)
                            .fontWeight(selectedMoverCategory == category ? .bold : .medium)
                            .foregroundColor(selectedMoverCategory == category ? .white : Color.pokemon.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                selectedMoverCategory == category
                                    ? categoryColor(category)
                                    : Color.pokemon.surface
                            )
                            .cornerRadius(16)
                    }
                }
                Spacer()
            }

            // Cards
            if isLoadingMovers {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pokemon.surface)
                            .frame(width: 160, height: 220)
                            .overlay(ProgressView().tint(Color.pokemon.primary))
                    }
                }
            } else if currentMoverCards.isEmpty {
                // Fallback to static cards when API is unavailable
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button { selectedTab = 1 } label: {
                            NewsAlertCard(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Top Gainers",
                                subtitle: "Rising this week",
                                color: Color.pokemon.positive
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button { selectedTab = 1 } label: {
                            NewsAlertCard(
                                icon: "flame.fill",
                                title: "Hot Cards",
                                subtitle: "Most tracked",
                                color: .orange
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button { selectedTab = 3 } label: {
                            NewsAlertCard(
                                icon: "bell.fill",
                                title: "Price Alerts",
                                subtitle: "Set up alerts",
                                color: .blue
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(currentMoverCards) { moverCard in
                            MarketMoverCardView(
                                card: moverCard,
                                category: selectedMoverCategory
                            )
                            .onTapGesture {
                                Task { await loadMarketMoverCard(moverCard) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryColor(_ category: MoverCategory) -> Color {
        switch category {
        case .gainers: return Color.pokemon.positive
        case .losers: return Color.pokemon.negative
        case .hot: return .orange
        }
    }

    // MARK: - Trending Cards Section

    private var trendingCardsSection: some View {
        CardCarousel(title: "Trending Cards", showViewAll: true, viewAllAction: { selectedTab = 1 }) {
            ForEach(trendingCards) { card in
                NavigationLink(destination: CardDetailView(card: card)) {
                    FeaturedCardView(
                        card: card,
                        showPriceChange: false
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Scan Card",
                    icon: "camera.fill",
                    color: Color.pokemon.primary
                ) {
                    selectedTab = 2
                }

                QuickActionButton(
                    title: "Search",
                    icon: "magnifyingglass",
                    color: Color.pokemon.gold
                ) {
                    selectedTab = 1
                }

                QuickActionButton(
                    title: "Portfolio",
                    icon: "folder.fill",
                    color: Color.pokemon.gold.opacity(0.8)
                ) {
                    selectedTab = 3
                }
            }
        }
    }

    // MARK: - Recent Additions

    private var recentAdditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Additions")
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)
                Spacer()
                NavigationLink("View All") {
                    PortfolioView()
                }
                .font(.caption)
                .foregroundColor(Color.pokemon.primary)
            }

            ForEach(collection.prefix(3), id: \.cardId) { collectionCard in
                RecentCardRow(card: collectionCard)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await loadRecentCard(collectionCard) }
                    }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Color.pokemon.gold)

            Text("Start Your Collection")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.pokemon.textPrimary)

            Text("Scan your first Pokemon card or search for cards to add to your portfolio.")
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Recent Card Row

struct RecentCardRow: View {
    let card: CollectionCard

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: card.imageSmall)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.pokemon.surface)
            }
            .frame(width: 40, height: 56)
            .cornerRadius(4)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.pokemon.textPrimary)

                Text(card.setName)
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(card.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.pokemon.gold)

                Text("×\(card.quantity)")
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)
            }
        }
        .padding()
        .background(Color.pokemon.surface)
        .cornerRadius(12)
    }
}

#Preview {
    HomeView(selectedTab: .constant(0))
        .modelContainer(for: CollectionCard.self, inMemory: true)
}
