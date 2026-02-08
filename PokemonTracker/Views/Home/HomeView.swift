import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var collection: [CollectionCard]
    @State private var trendingCards: [Card] = []
    @State private var isLoading = false
    @State private var showScrollToTop = false
    @State private var scrollOffset: CGFloat = 0

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
            .task {
                await loadTrendingCards()
            }
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
                colors: [Color.pokemon.primary.opacity(0.3), Color.pokemon.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    // MARK: - Market Movers Carousel

    private var marketMoversCarousel: some View {
        CardCarousel(title: "Market Movers", showViewAll: true) {
            NewsAlertCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "Today's TCG Recap",
                subtitle: "Daily market summary",
                color: Color.pokemon.primary
            )

            NewsAlertCard(
                icon: "flame.fill",
                title: "Hot Cards",
                subtitle: "Trending this week",
                color: .orange
            )

            NewsAlertCard(
                icon: "arrow.up.circle.fill",
                title: "Top Gainers",
                subtitle: "+15% average gain",
                color: Color.pokemon.positive
            )

            NewsAlertCard(
                icon: "bell.fill",
                title: "Price Alerts",
                subtitle: "3 cards moved",
                color: .blue
            )
        }
    }

    // MARK: - Trending Cards Section

    private var trendingCardsSection: some View {
        CardCarousel(title: "Trending Cards", showViewAll: true) {
            ForEach(trendingCards) { card in
                NavigationLink(destination: CardDetailView(card: card)) {
                    FeaturedCardView(
                        card: card,
                        showPriceChange: true,
                        priceChangePercent: Double.random(in: -15...25) // Simulated for demo
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
                    // Navigate to scanner - handled by tab
                }

                QuickActionButton(
                    title: "Search",
                    icon: "magnifyingglass",
                    color: Color.blue
                ) {
                    // Navigate to search - handled by tab
                }

                QuickActionButton(
                    title: "Portfolio",
                    icon: "folder.fill",
                    color: Color.green
                ) {
                    // Navigate to portfolio - handled by tab
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

            ForEach(collection.prefix(3), id: \.cardId) { card in
                RecentCardRow(card: card)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Color.pokemon.primary)

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
                    .foregroundColor(Color.pokemon.textPrimary)

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
    HomeView()
        .modelContainer(for: CollectionCard.self, inMemory: true)
}
