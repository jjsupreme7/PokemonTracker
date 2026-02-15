import Foundation

/// Service for fetching live card prices from PokeTrace API (TCGPlayer + eBay data)
actor PokeTraceService {
    static let shared = PokeTraceService()

    private let baseURL = Config.poketraceBaseURL
    private let apiKey = Config.poketraceAPIKey

    // Cache to reduce API calls
    private var priceCache: [String: CachedPokeTracePrice] = [:]
    private let cacheExpiration: TimeInterval = 1800 // 30 minutes

    private init() {}

    // MARK: - Public Methods

    /// Search for a card and return pricing data
    func fetchPrices(cardName: String, setName: String? = nil, cardNumber: String? = nil) async throws -> PokeTraceCard? {
        // Build cache key
        let cacheKey = "\(cardName)-\(setName ?? "")-\(cardNumber ?? "")"
        if let cached = priceCache[cacheKey], !cached.isExpired {
            return cached.card
        }

        // Build search query
        var searchQuery = cardName
        if let setName = setName {
            searchQuery += " \(setName)"
        }

        var components = URLComponents(string: "\(baseURL)/cards")!
        components.queryItems = [
            URLQueryItem(name: "search", value: searchQuery),
            URLQueryItem(name: "limit", value: "10")
        ]

        guard let url = components.url else {
            throw PokeTraceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let httpResponse = response as? HTTPURLResponse
            let code = httpResponse?.statusCode ?? 500
            print("[PokeTrace] API error: HTTP \(code)")
            throw PokeTraceError.apiError(statusCode: code)
        }

        let result: PokeTraceResponse
        do {
            result = try JSONDecoder().decode(PokeTraceResponse.self, from: data)
            print("[PokeTrace] Decoded \(result.data.count) cards")
        } catch {
            print("[PokeTrace] JSON decode error: \(error)")
            if let raw = String(data: data.prefix(500), encoding: .utf8) {
                print("[PokeTrace] Raw response: \(raw)")
            }
            throw error
        }

        // Find the best match
        let match = findBestMatch(
            cards: result.data,
            name: cardName,
            setName: setName,
            cardNumber: cardNumber
        )

        // Cache the result
        priceCache[cacheKey] = CachedPokeTracePrice(card: match, timestamp: Date())

        return match
    }

    /// Get a simple market price for a card (NM TCGPlayer price, fallback to eBay)
    func getMarketPrice(cardName: String, setName: String? = nil, cardNumber: String? = nil) async throws -> Double? {
        guard let card = try await fetchPrices(cardName: cardName, setName: setName, cardNumber: cardNumber) else {
            return nil
        }
        return card.bestPrice
    }

    // MARK: - Matching

    private func findBestMatch(cards: [PokeTraceCard], name: String, setName: String?, cardNumber: String?) -> PokeTraceCard? {
        guard !cards.isEmpty else { return nil }

        let nameLower = name.lowercased()

        // Try exact name + number match first
        if let number = cardNumber {
            for card in cards {
                if card.name.lowercased() == nameLower && (card.cardNumber?.contains(number) == true) {
                    return card
                }
            }
        }

        // Try exact name match
        for card in cards {
            if card.name.lowercased() == nameLower {
                return card
            }
        }

        // Try name contains match
        for card in cards {
            if card.name.lowercased().contains(nameLower) || nameLower.contains(card.name.lowercased()) {
                return card
            }
        }

        // Fall back to first result
        return cards.first
    }
}

// MARK: - Response Models

struct PokeTraceResponse: Codable {
    let data: [PokeTraceCard]
    let pagination: PokeTracePagination?
}

struct PokeTracePagination: Codable {
    let hasMore: Bool?
    let nextCursor: String?
    let count: Int?
}

struct PokeTraceCard: Codable {
    let id: String
    let name: String
    let cardNumber: String?
    let set: PokeTraceSet?
    let variant: String?
    let rarity: String?
    let image: String?
    let game: String?
    let market: String?
    let currency: String?
    let prices: PokeTracePrices?
    let lastUpdated: String?

    /// Best available price (NM TCGPlayer > NM eBay > LP TCGPlayer > any available)
    var bestPrice: Double? {
        let tcg = prices?.tcgplayer
        let ebay = prices?.ebay

        if let price = tcg?.nearMint?.avg { return price }
        if let price = ebay?.nearMint?.avg { return price }
        if let price = tcg?.lightlyPlayed?.avg { return price }
        if let price = ebay?.lightlyPlayed?.avg { return price }
        if let price = tcg?.moderatelyPlayed?.avg { return price }
        return nil
    }

    /// TCGPlayer NM average price
    var tcgPlayerPrice: Double? {
        prices?.tcgplayer?.nearMint?.avg
    }

    /// eBay NM average price
    var ebayPrice: Double? {
        prices?.ebay?.nearMint?.avg
    }

    /// Total sale count across sources
    var totalSaleCount: Int {
        let tcgCount = prices?.tcgplayer?.nearMint?.saleCount ?? 0
        let ebayCount = prices?.ebay?.nearMint?.saleCount ?? 0
        return tcgCount + ebayCount
    }
}

struct PokeTraceSet: Codable {
    let slug: String?
    let name: String?
}

struct PokeTracePrices: Codable {
    let ebay: PokeTraceConditionPrices?
    let tcgplayer: PokeTraceConditionPrices?
}

struct PokeTraceConditionPrices: Codable {
    let nearMint: PokeTracePricePoint?
    let lightlyPlayed: PokeTracePricePoint?
    let moderatelyPlayed: PokeTracePricePoint?
    let heavilyPlayed: PokeTracePricePoint?
    let damaged: PokeTracePricePoint?

    enum CodingKeys: String, CodingKey {
        case nearMint = "NEAR_MINT"
        case lightlyPlayed = "LIGHTLY_PLAYED"
        case moderatelyPlayed = "MODERATELY_PLAYED"
        case heavilyPlayed = "HEAVILY_PLAYED"
        case damaged = "DAMAGED"
    }
}

struct PokeTracePricePoint: Codable {
    let avg: Double?
    let low: Double?
    let high: Double?
    let saleCount: Int?
    let lastUpdated: String?
    let avg7d: Double?
    let avg30d: Double?
}

// MARK: - Cache

private struct CachedPokeTracePrice {
    let card: PokeTraceCard?
    let timestamp: Date

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 1800
    }
}

// MARK: - Errors

enum PokeTraceError: Error, LocalizedError {
    case invalidURL
    case apiError(statusCode: Int)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid PokeTrace API URL"
        case .apiError(let code):
            return "PokeTrace API error: \(code)"
        case .noResults:
            return "No pricing data found"
        }
    }
}
