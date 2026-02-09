import Foundation

/// Service for searching Pokemon cards via PokeTrace API
/// Provides pricing from eBay, TCGPlayer, and CardMarket
actor PokemonTCGService {
    static let shared = PokemonTCGService()

    private let baseURL = Config.poketraceBaseURL
    private let apiKey = Config.poketraceAPIKey

    private init() {}

    // MARK: - Search Cards

    /// Search for cards by name
    func searchCards(name: String, page: Int = 1, pageSize: Int = 20) async throws -> [Card] {
        var components = URLComponents(string: "\(baseURL)/cards")!
        components.queryItems = [
            URLQueryItem(name: "search", value: name),
            URLQueryItem(name: "limit", value: String(pageSize)),
        ]

        guard let url = components.url else {
            throw PokemonTCGError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PokemonTCGError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PokemonTCGError.httpError(statusCode: httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(PokeTraceSearchResponse.self, from: data)
        let cards = (result.data ?? []).filter { $0.image != nil }
        return cards.map { $0.toCard() }
    }

    /// Search for cards by set ID and number
    func searchCard(setId: String, number: String) async throws -> Card? {
        let cards = try await searchCards(name: "\(setId) \(number)", pageSize: 5)
        return cards.first { $0.number == number }
    }

    /// Search with a custom query string
    func searchCards(query: String, page: Int = 1, pageSize: Int = 20) async throws -> [Card] {
        return try await searchCards(name: query, page: page, pageSize: pageSize)
    }

    // MARK: - Get Card Detail with Prices

    /// Get a specific card by its PokeTrace ID, including prices
    func getCard(id: String) async throws -> Card {
        guard let url = URL(string: "\(baseURL)/cards/\(id)") else {
            throw PokemonTCGError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PokemonTCGError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PokemonTCGError.httpError(statusCode: httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(PokeTraceDetailResponse.self, from: data)
        return result.data.toCard()
    }

    // MARK: - Fetch Prices for Cards

    /// Fetch prices for multiple cards in parallel
    func fetchPrices(for cards: [Card]) async -> [Card] {
        await withTaskGroup(of: Card.self, returning: [Card].self) { group in
            for card in cards {
                group.addTask {
                    do {
                        return try await self.getCard(id: card.id)
                    } catch {
                        return card
                    }
                }
            }

            var results: [Card] = []
            for await card in group {
                results.append(card)
            }
            return results
        }
    }
}

// MARK: - PokeTrace API Response Types

private struct PokeTraceSearchResponse: Codable {
    let data: [PokeTraceCard]?
}

private struct PokeTraceDetailResponse: Codable {
    let data: PokeTraceDetailCard
}

private struct PokeTraceCard: Codable {
    let id: String
    let name: String
    let cardNumber: String?
    let set: PokeTraceSet?
    let variant: String?
    let rarity: String?
    let image: String?
    let market: String?
    let currency: String?

    func toCard() -> Card {
        let setName = set?.name ?? "Unknown Set"
        let setSlug = set?.slug ?? "unknown"
        let number = cardNumber ?? ""
        let imageURL = image ?? ""

        return Card(
            id: id,
            name: name,
            supertype: nil,
            subtypes: nil,
            hp: nil,
            types: nil,
            evolvesFrom: nil,
            abilities: nil,
            attacks: nil,
            weaknesses: nil,
            resistances: nil,
            retreatCost: nil,
            convertedRetreatCost: nil,
            set: CardSet(
                id: setSlug,
                name: setName,
                series: "",
                printedTotal: nil,
                total: nil,
                legalities: nil,
                ptcgoCode: nil,
                releaseDate: nil,
                updatedAt: nil,
                images: SetImages(symbol: "", logo: "")
            ),
            number: number,
            artist: nil,
            rarity: rarity ?? variant,
            flavorText: nil,
            nationalPokedexNumbers: nil,
            legalities: nil,
            images: CardImages(small: imageURL, large: imageURL),
            tcgplayer: nil,
            cardmarket: nil
        )
    }
}

private struct PokeTraceDetailCard: Codable {
    let id: String
    let name: String
    let cardNumber: String?
    let set: PokeTraceSet?
    let variant: String?
    let rarity: String?
    let image: String?
    let prices: PokeTracePrices?

    func toCard() -> Card {
        let setName = set?.name ?? "Unknown Set"
        let setSlug = set?.slug ?? "unknown"
        let number = cardNumber ?? ""
        let imageURL = image ?? ""

        // Extract best price from PokeTrace prices
        let tcgPlayerPrices = extractTCGPlayerPrices()

        return Card(
            id: id,
            name: name,
            supertype: nil,
            subtypes: nil,
            hp: nil,
            types: nil,
            evolvesFrom: nil,
            abilities: nil,
            attacks: nil,
            weaknesses: nil,
            resistances: nil,
            retreatCost: nil,
            convertedRetreatCost: nil,
            set: CardSet(
                id: setSlug,
                name: setName,
                series: "",
                printedTotal: nil,
                total: nil,
                legalities: nil,
                ptcgoCode: nil,
                releaseDate: nil,
                updatedAt: nil,
                images: SetImages(symbol: "", logo: "")
            ),
            number: number,
            artist: nil,
            rarity: rarity ?? variant,
            flavorText: nil,
            nationalPokedexNumbers: nil,
            legalities: nil,
            images: CardImages(small: imageURL, large: imageURL),
            tcgplayer: tcgPlayerPrices,
            cardmarket: nil
        )
    }

    private func extractTCGPlayerPrices() -> TCGPlayer? {
        guard let prices = prices else { return nil }

        // Try TCGPlayer first, then eBay
        let tcg = prices.tcgplayer
        let ebay = prices.ebay

        var marketPrice: Double?

        // TCGPlayer Near Mint > Lightly Played
        if let nm = tcg?["NEAR_MINT"]?.avg, nm > 0 { marketPrice = nm }
        else if let lp = tcg?["LIGHTLY_PLAYED"]?.avg, lp > 0 { marketPrice = lp }
        // eBay fallback
        else if let nm = ebay?["NEAR_MINT"]?.avg, nm > 0 { marketPrice = nm }
        else if let lp = ebay?["LIGHTLY_PLAYED"]?.avg, lp > 0 { marketPrice = lp }
        // Any TCGPlayer condition
        else if let tcg = tcg {
            marketPrice = tcg.values.first(where: { ($0.avg ?? 0) > 0 })?.avg
        }
        // Any eBay condition
        else if let ebay = ebay {
            marketPrice = ebay.values.first(where: { ($0.avg ?? 0) > 0 })?.avg
        }

        guard let price = marketPrice else { return nil }

        return TCGPlayer(
            url: nil,
            updatedAt: nil,
            prices: TCGPlayerPrices(
                holofoil: PriceData(low: nil, mid: nil, high: nil, market: price, directLow: nil),
                reverseHolofoil: nil,
                normal: nil,
                firstEditionHolofoil: nil,
                firstEditionNormal: nil
            )
        )
    }
}

private struct PokeTraceSet: Codable {
    let slug: String?
    let name: String?
}

private struct PokeTracePrices: Codable {
    let tcgplayer: [String: PokeTracePriceEntry]?
    let ebay: [String: PokeTracePriceEntry]?
}

private struct PokeTracePriceEntry: Codable {
    let avg: Double?
    let low: Double?
    let high: Double?
}

// MARK: - Errors

enum PokemonTCGError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
