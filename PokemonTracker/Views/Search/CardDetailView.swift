import SwiftUI
import SwiftData

struct CardDetailView: View {
    let card: Card

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var quantity = 1
    @State private var purchasePrice = ""
    @State private var addedToCollection = false

    // PokeTrace pricing state
    @State private var pokeTraceCard: PokeTraceCard?
    @State private var isLoadingPrices = true
    @State private var priceError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Card Image
                cardImageSection

                // Live Price Section
                livePriceSection

                // Card Info
                cardInfoSection

                // Add to Collection Button
                addButton
            }
            .padding()
        }
        .background(Color.pokemon.background)
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddSheet) {
            addToCollectionSheet
        }
        .task {
            await loadPokeTracePrices()
        }
    }

    // MARK: - Card Image

    private var cardImageSection: some View {
        AsyncImage(url: URL(string: card.images.large)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pokemon.surface)
                .overlay(
                    ProgressView()
                        .tint(Color.pokemon.primary)
                )
        }
        .frame(maxWidth: 280)
        .cornerRadius(12)
        .shadow(color: Color.pokemon.gold.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    // MARK: - Live Price Section

    private var livePriceSection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Live Market Price")
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)
                Spacer()
                if isLoadingPrices {
                    ProgressView()
                        .tint(Color.pokemon.primary)
                }
            }

            if let error = priceError {
                // Error state - fall back to Pokemon TCG API price
                VStack(spacing: 8) {
                    Text(card.formattedPrice)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color.pokemon.textPrimary)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color.pokemon.textSecondary)
                }
            } else if let ptCard = pokeTraceCard {
                // PokeTrace prices
                VStack(spacing: 16) {
                    // Main price
                    if let bestPrice = ptCard.bestPrice {
                        Text(String(format: "$%.2f", bestPrice))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color.pokemon.gold)
                    } else {
                        Text("N/A")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color.pokemon.textSecondary)
                    }

                    // TCGPlayer + eBay side by side
                    HStack(spacing: 20) {
                        // TCGPlayer prices
                        if let tcg = ptCard.prices?.tcgplayer {
                            VStack(spacing: 8) {
                                Text("TCGPlayer")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.pokemon.primary)

                                if let nm = tcg.nearMint {
                                    ConditionPriceRow(condition: "NM", avg: nm.avg, low: nm.low, high: nm.high, sales: nm.saleCount)
                                }
                                if let lp = tcg.lightlyPlayed {
                                    ConditionPriceRow(condition: "LP", avg: lp.avg, low: lp.low, high: lp.high, sales: lp.saleCount)
                                }
                                if let mp = tcg.moderatelyPlayed {
                                    ConditionPriceRow(condition: "MP", avg: mp.avg, low: mp.low, high: mp.high, sales: mp.saleCount)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.pokemon.background)
                            .frame(width: 1)

                        // eBay prices
                        if let ebay = ptCard.prices?.ebay {
                            VStack(spacing: 8) {
                                Text("eBay Sold")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)

                                if let nm = ebay.nearMint {
                                    ConditionPriceRow(condition: "NM", avg: nm.avg, low: nm.low, high: nm.high, sales: nm.saleCount)
                                }
                                if let lp = ebay.lightlyPlayed {
                                    ConditionPriceRow(condition: "LP", avg: lp.avg, low: lp.low, high: lp.high, sales: lp.saleCount)
                                }
                                if let mp = ebay.moderatelyPlayed {
                                    ConditionPriceRow(condition: "MP", avg: mp.avg, low: mp.low, high: mp.high, sales: mp.saleCount)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Sale count + last updated
                    if ptCard.totalSaleCount > 0 {
                        Text("Based on \(ptCard.totalSaleCount) NM sales")
                            .font(.caption2)
                            .foregroundColor(Color.pokemon.textSecondary)
                    }
                }
            } else if !isLoadingPrices {
                // Fallback to Pokemon TCG API price
                Text(card.formattedPrice)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color.pokemon.textPrimary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.pokemon.surface)
        .cornerRadius(16)
    }

    // MARK: - Card Info

    private var cardInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Card Details")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            VStack(spacing: 12) {
                InfoRow(label: "Set", value: card.set.name)
                InfoRow(label: "Number", value: card.setIdentifier)

                if let rarity = card.rarity {
                    InfoRow(label: "Rarity", value: rarity)
                }

                if let supertype = card.supertype {
                    InfoRow(label: "Type", value: supertype)
                }

                if let hp = card.hp {
                    InfoRow(label: "HP", value: hp)
                }

                if let artist = card.artist {
                    InfoRow(label: "Artist", value: artist)
                }
            }
        }
        .padding()
        .background(Color.pokemon.surface)
        .cornerRadius(16)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            HStack {
                Image(systemName: addedToCollection ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(addedToCollection ? "Added to Collection" : "Add to Collection")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(addedToCollection ? Color.pokemon.positive : Color.pokemon.primary)
            .cornerRadius(12)
        }
        .disabled(addedToCollection)
    }

    // MARK: - Add Sheet

    private var addToCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Quantity") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }

                Section("Purchase Info (Optional)") {
                    TextField("Purchase Price", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addToCollection()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Add to Collection

    private func addToCollection() {
        let price = Double(purchasePrice)
        let collectionCard = CollectionCard(
            from: card,
            quantity: quantity,
            purchasePrice: price
        )

        // Use PokeTrace live price if available (more reliable than Pokemon TCG API)
        if let livePrice = pokeTraceCard?.bestPrice {
            collectionCard.currentPrice = livePrice
            collectionCard.lastPriceUpdate = Date()
        }

        modelContext.insert(collectionCard)

        do {
            try modelContext.save()
            addedToCollection = true
            showingAddSheet = false

            // Save to Supabase in the background
            let cardToSync = collectionCard
            Task {
                await saveToSupabase(cardToSync)
            }
        } catch {
            print("Failed to save: \(error)")
        }
    }

    private func saveToSupabase(_ card: CollectionCard) async {
        guard AuthService.shared.isAuthenticated else { return }

        let dto = CollectionCardDTO(
            cardId: card.cardId,
            name: card.name,
            setId: card.setId,
            setName: card.setName,
            number: card.number,
            rarity: card.rarity,
            variant: card.variant,
            imageSmall: card.imageSmall,
            imageLarge: card.imageLarge,
            quantity: card.quantity,
            purchasePrice: card.purchasePrice,
            currentPrice: card.currentPrice,
            dateAdded: ISO8601DateFormatter().string(from: card.dateAdded),
            updatedAt: ISO8601DateFormatter().string(from: card.updatedAt)
        )

        do {
            let response = try await APIService.shared.addCard(dto)
            await MainActor.run {
                card.markAsSynced(serverId: UUID(uuidString: response.data.id))
            }
        } catch {
            print("Failed to sync card to Supabase: \(error)")
        }
    }

    // MARK: - Load PokeTrace Prices

    private func loadPokeTracePrices() async {
        await MainActor.run {
            isLoadingPrices = true
            priceError = nil
        }

        do {
            print("[PokeTrace] Fetching prices for: \(card.name) | Set: \(card.set.name) | Number: \(card.number)")
            let result = try await PokeTraceService.shared.fetchPrices(
                cardName: card.name,
                setName: card.set.name,
                cardNumber: card.number
            )

            await MainActor.run {
                self.pokeTraceCard = result
                self.isLoadingPrices = false
                if let r = result {
                    print("[PokeTrace] Got price: \(r.bestPrice ?? -1) for \(r.name)")
                } else {
                    self.priceError = "No live pricing data found"
                    print("[PokeTrace] No matching card found")
                }
            }
        } catch {
            print("[PokeTrace] Error fetching prices: \(error)")
            await MainActor.run {
                self.priceError = "Could not load live prices"
                self.isLoadingPrices = false
            }
        }
    }
}

// MARK: - Condition Price Row

struct ConditionPriceRow: View {
    let condition: String
    let avg: Double?
    let low: Double?
    let high: Double?
    let sales: Int?

    var body: some View {
        HStack(spacing: 4) {
            Text(condition)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(Color.pokemon.textSecondary)
                .frame(width: 24, alignment: .leading)

            if let avg = avg {
                Text(String(format: "$%.2f", avg))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.pokemon.textPrimary)
            } else {
                Text("N/A")
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)
            }

            Spacer()

            if let sales = sales, sales > 0 {
                Text("\(sales) sold")
                    .font(.caption2)
                    .foregroundColor(Color.pokemon.textSecondary)
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: Card(
            id: "sv1-25",
            name: "Pikachu",
            supertype: "Pokemon",
            subtypes: ["Basic"],
            hp: "60",
            types: ["Lightning"],
            evolvesFrom: nil,
            abilities: nil,
            attacks: nil,
            weaknesses: nil,
            resistances: nil,
            retreatCost: nil,
            convertedRetreatCost: nil,
            set: CardSet(
                id: "sv1",
                name: "Scarlet & Violet",
                series: "Scarlet & Violet",
                printedTotal: 198,
                total: 198,
                legalities: nil,
                ptcgoCode: nil,
                releaseDate: "2023/03/31",
                updatedAt: nil,
                images: SetImages(symbol: "", logo: "")
            ),
            number: "25",
            artist: "Mitsuhiro Arita",
            rarity: "Common",
            flavorText: nil,
            nationalPokedexNumbers: [25],
            legalities: nil,
            images: CardImages(
                small: "https://images.pokemontcg.io/sv1/25.png",
                large: "https://images.pokemontcg.io/sv1/25_hires.png"
            ),
            tcgplayer: nil,
            cardmarket: nil
        ))
    }
}
