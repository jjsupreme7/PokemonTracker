import SwiftUI
import SwiftData

struct CardDetailView: View {
    let card: Card

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var quantity = 1
    @State private var purchasePrice = ""
    @State private var addedToCollection = false

    // eBay pricing state
    @State private var ebayPriceData: EbayPriceData?
    @State private var isLoadingEbay = false
    @State private var ebayError: String?
    @State private var selectedPriceSource: PriceSource = .tcgplayer

    enum PriceSource: String, CaseIterable {
        case tcgplayer = "TCGPlayer"
        case ebay = "eBay"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Card Image
                cardImageSection

                // Price Source Picker
                priceSourcePicker

                // Price Section
                priceSection

                // eBay Price Section (if selected)
                if selectedPriceSource == .ebay {
                    ebayPriceSection
                }

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
            await loadEbayPrices()
        }
    }

    // MARK: - Price Source Picker

    private var priceSourcePicker: some View {
        Picker("Price Source", selection: $selectedPriceSource) {
            ForEach(PriceSource.allCases, id: \.self) { source in
                Text(source.rawValue).tag(source)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
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

    // MARK: - Price Section

    private var priceSection: some View {
        VStack(spacing: 12) {
            Text("Market Price")
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)

            Text(card.formattedPrice)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color.pokemon.textPrimary)

            // Price variants if available
            if let tcgPrices = card.tcgplayer?.prices {
                HStack(spacing: 16) {
                    if let normal = tcgPrices.normal?.market {
                        PriceVariantBadge(label: "Normal", price: normal)
                    }
                    if let holo = tcgPrices.holofoil?.market {
                        PriceVariantBadge(label: "Holo", price: holo)
                    }
                    if let reverse = tcgPrices.reverseHolofoil?.market {
                        PriceVariantBadge(label: "Reverse", price: reverse)
                    }
                }
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

        modelContext.insert(collectionCard)

        do {
            try modelContext.save()
            addedToCollection = true
            showingAddSheet = false
        } catch {
            print("Failed to save: \(error)")
        }
    }

    // MARK: - eBay Price Section

    private var ebayPriceSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundColor(.blue)
                Text("eBay Market Data")
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)
                Spacer()

                if isLoadingEbay {
                    ProgressView()
                        .tint(Color.pokemon.primary)
                }
            }

            if let error = ebayError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color.pokemon.textSecondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else if let priceData = ebayPriceData {
                // Price statistics
                VStack(spacing: 16) {
                    // Average price (prominent)
                    VStack(spacing: 4) {
                        Text("Average Sold Price")
                            .font(.caption)
                            .foregroundColor(Color.pokemon.textSecondary)
                        Text(priceData.formattedAveragePrice)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.pokemon.gold)
                    }

                    // Price range and sample size
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("Low")
                                .font(.caption2)
                                .foregroundColor(Color.pokemon.textSecondary)
                            Text(priceData.lowestPrice.map { String(format: "$%.2f", $0) } ?? "N/A")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.pokemon.positive)
                        }

                        VStack(spacing: 4) {
                            Text("Median")
                                .font(.caption2)
                                .foregroundColor(Color.pokemon.textSecondary)
                            Text(priceData.medianPrice.map { String(format: "$%.2f", $0) } ?? "N/A")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.pokemon.textPrimary)
                        }

                        VStack(spacing: 4) {
                            Text("High")
                                .font(.caption2)
                                .foregroundColor(Color.pokemon.textSecondary)
                            Text(priceData.highestPrice.map { String(format: "$%.2f", $0) } ?? "N/A")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.pokemon.negative)
                        }
                    }
                    .padding(.horizontal)

                    // Sample info
                    Text("Based on \(priceData.sampleSize) listings")
                        .font(.caption2)
                        .foregroundColor(Color.pokemon.textSecondary)

                    // Recent sales
                    if !priceData.recentSales.isEmpty {
                        Divider()
                            .background(Color.pokemon.background)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Listings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.pokemon.textPrimary)

                            ForEach(priceData.recentSales.prefix(5), id: \.title) { sale in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sale.title)
                                            .font(.caption)
                                            .foregroundColor(Color.pokemon.textPrimary)
                                            .lineLimit(1)
                                        Text(sale.condition)
                                            .font(.caption2)
                                            .foregroundColor(Color.pokemon.textSecondary)
                                    }
                                    Spacer()
                                    Text(sale.formattedPrice)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.pokemon.gold)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            } else if !isLoadingEbay {
                Text("No eBay data available")
                    .font(.subheadline)
                    .foregroundColor(Color.pokemon.textSecondary)
            }
        }
        .padding()
        .background(Color.pokemon.surface)
        .cornerRadius(16)
    }

    // MARK: - Load eBay Prices

    private func loadEbayPrices() async {
        isLoadingEbay = true
        ebayError = nil

        do {
            let priceData = try await EbayPriceService.shared.fetchSoldPrices(
                cardName: card.name,
                setName: card.set.name,
                cardNumber: card.number
            )

            await MainActor.run {
                self.ebayPriceData = priceData
                self.isLoadingEbay = false
            }
        } catch let error as EbayError {
            await MainActor.run {
                if case .authenticationFailed = error {
                    self.ebayError = "eBay API not configured. Add your API keys to enable."
                } else {
                    self.ebayError = error.localizedDescription
                }
                self.isLoadingEbay = false
            }
        } catch {
            await MainActor.run {
                self.ebayError = "Failed to load eBay prices"
                self.isLoadingEbay = false
            }
        }
    }
}

// MARK: - Price Variant Badge

struct PriceVariantBadge: View {
    let label: String
    let price: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.pokemon.textSecondary)

            Text(String(format: "$%.2f", price))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color.pokemon.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.pokemon.background)
        .cornerRadius(8)
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
