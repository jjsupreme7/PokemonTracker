import SwiftUI

// MARK: - Horizontal Card Carousel

struct CardCarousel<Content: View>: View {
    let title: String
    let showViewAll: Bool
    let viewAllAction: (() -> Void)?
    let content: Content

    init(
        title: String,
        showViewAll: Bool = true,
        viewAllAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showViewAll = showViewAll
        self.viewAllAction = viewAllAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)

                Spacer()

                if showViewAll {
                    Button {
                        viewAllAction?()
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
            }

            // Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    content
                }
            }
        }
    }
}

// MARK: - Featured Card (for carousels)

struct FeaturedCardView: View {
    let card: Card
    let showPriceChange: Bool
    let priceChangePercent: Double?

    init(card: Card, showPriceChange: Bool = true, priceChangePercent: Double? = nil) {
        self.card = card
        self.showPriceChange = showPriceChange
        self.priceChangePercent = priceChangePercent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card Image with price change badge
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: card.images.small)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.pokemon.surface)
                        .overlay(
                            ProgressView()
                                .tint(Color.pokemon.primary)
                        )
                }
                .frame(width: 120, height: 168)
                .cornerRadius(8)

                // Price change badge
                if showPriceChange, let change = priceChangePercent {
                    let isPositive = change >= 0
                    Text(String(format: "%@%.1f%%", isPositive ? "+" : "", change))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isPositive ? Color.pokemon.positive : Color.pokemon.negative)
                        .cornerRadius(4)
                        .padding(6)
                }
            }

            // Card Info
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.pokemon.textPrimary)
                    .lineLimit(1)

                Text(card.set.name)
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)
                    .lineLimit(1)

                Text(card.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.pokemon.gold)
            }
            .frame(width: 120, alignment: .leading)
        }
        .padding(8)
        .background(Color.pokemon.surface)
        .cornerRadius(12)
    }
}

// MARK: - Market Signal Card (larger featured card)

struct MarketSignalCard: View {
    let card: Card
    let signal: String
    let description: String
    let priceChange: Double

    var body: some View {
        VStack(spacing: 12) {
            // Card Image
            AsyncImage(url: URL(string: card.images.large)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.pokemon.background)
                    .overlay(
                        ProgressView()
                            .tint(Color.pokemon.primary)
                    )
            }
            .frame(width: 140, height: 196)
            .cornerRadius(8)

            // Signal Badge
            Text(signal.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(signalColor)
                .cornerRadius(12)

            // Card Info
            VStack(spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)

                HStack(spacing: 4) {
                    Text(card.formattedPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color.pokemon.gold)

                    let isPositive = priceChange >= 0
                    HStack(spacing: 2) {
                        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text(String(format: "%@%.1f%%", isPositive ? "+" : "", priceChange))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(isPositive ? Color.pokemon.positive : Color.pokemon.negative)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    // Add to collection action
                } label: {
                    Text("+ Add")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color.pokemon.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.pokemon.background)
                        .cornerRadius(6)
                }

                Button {
                    // Buy action
                } label: {
                    Text("Buy")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.pokemon.primary)
                        .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.pokemon.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.pokemon.primary.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var signalColor: Color {
        switch signal.lowercased() {
        case "momentum", "rising", "hot":
            return Color.pokemon.positive
        case "dropping", "falling":
            return Color.pokemon.negative
        case "buyout", "spike":
            return Color.orange
        default:
            return Color.pokemon.primary
        }
    }
}

// MARK: - Scroll To Top Button

struct ScrollToTopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.pokemon.primary)
                .clipShape(Circle())
                .shadow(color: Color.pokemon.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Scrollable View with FAB

struct ScrollableView<Content: View>: View {
    let content: Content
    @State private var scrollOffset: CGFloat = 0
    @State private var showScrollToTop = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Anchor for scroll to top
                        Color.clear
                            .frame(height: 0)
                            .id("top")

                        content
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
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showScrollToTop = value < -200
                    }
                }

                // Scroll to top button
                if showScrollToTop {
                    ScrollToTopButton {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Refreshable Modifier Helper

extension View {
    func refreshableAsync(action: @escaping () async -> Void) -> some View {
        self.refreshable {
            await action()
        }
    }
}

// MARK: - News/Alert Card (Horizontal scroll item)

struct NewsAlertCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.pokemon.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.pokemon.surface)
        .cornerRadius(12)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // News Carousel
            CardCarousel(title: "Market Movers") {
                NewsAlertCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Charizard hits $500",
                    subtitle: "New record high",
                    color: .green
                )
                NewsAlertCard(
                    icon: "exclamationmark.triangle",
                    title: "Market Alert",
                    subtitle: "High volatility detected",
                    color: .orange
                )
            }
            .padding(.horizontal)

            ScrollToTopButton {
                print("Scroll to top")
            }
        }
    }
    .background(Color.pokemon.background)
}
