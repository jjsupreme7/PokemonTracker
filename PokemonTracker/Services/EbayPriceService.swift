import Foundation

// MARK: - eBay Price Service

/// Service for fetching real-time sold prices from eBay
/// Note: Requires eBay Developer account and OAuth tokens
/// Sign up at: https://developer.ebay.com/
actor EbayPriceService {
    static let shared = EbayPriceService()

    // eBay API configuration
    // TODO: Replace with your eBay API credentials
    private let clientId = "YOUR_EBAY_CLIENT_ID"
    private let clientSecret = "YOUR_EBAY_CLIENT_SECRET"
    private var accessToken: String?
    private var tokenExpiration: Date?

    // eBay Browse API base URL (Production)
    private let baseURL = "https://api.ebay.com/buy/browse/v1"
    private let authURL = "https://api.ebay.com/identity/v1/oauth2/token"

    // Cache to reduce API calls
    private var priceCache: [String: CachedPrice] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1 hour

    private init() {}

    // MARK: - Public Methods

    /// Fetch recent sold prices for a Pokemon card
    /// - Parameters:
    ///   - cardName: The card name (e.g., "Charizard")
    ///   - setName: The set name (e.g., "Base Set")
    ///   - cardNumber: Optional card number for more precise matching
    /// - Returns: EbayPriceData with recent sales info
    func fetchSoldPrices(cardName: String, setName: String, cardNumber: String? = nil) async throws -> EbayPriceData {
        // Check cache first
        let cacheKey = "\(cardName)-\(setName)-\(cardNumber ?? "")"
        if let cached = priceCache[cacheKey], !cached.isExpired {
            return cached.data
        }

        // Ensure we have valid access token
        try await ensureValidToken()

        guard let token = accessToken else {
            throw EbayError.authenticationFailed
        }

        // Build search query
        var searchQuery = "Pokemon TCG \(cardName) \(setName)"
        if let number = cardNumber {
            searchQuery += " \(number)"
        }

        // Search sold items using Browse API
        // Note: Browse API shows active listings, not sold items directly
        // For sold items, you'd typically use Finding API with SOLD filter
        // This implementation shows active listings as a proxy

        var components = URLComponents(string: "\(baseURL)/item_summary/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "category_ids", value: "183454"), // Pokemon TCG category
            URLQueryItem(name: "filter", value: "buyingOptions:{FIXED_PRICE|AUCTION}"),
            URLQueryItem(name: "sort", value: "price"),
            URLQueryItem(name: "limit", value: "50")
        ]

        guard let url = components.url else {
            throw EbayError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("EBAY-US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EbayError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw EbayError.apiError(statusCode: httpResponse.statusCode)
        }

        let searchResult = try JSONDecoder().decode(EbaySearchResponse.self, from: data)

        // Process results to extract price data
        let priceData = processSalesData(searchResult)

        // Cache the result
        priceCache[cacheKey] = CachedPrice(data: priceData, timestamp: Date())

        return priceData
    }

    /// Get market price estimate based on recent eBay data
    func getMarketPrice(cardName: String, setName: String, cardNumber: String? = nil) async throws -> Double? {
        let priceData = try await fetchSoldPrices(cardName: cardName, setName: setName, cardNumber: cardNumber)
        return priceData.averagePrice
    }

    // MARK: - Authentication

    private func ensureValidToken() async throws {
        // Check if current token is still valid
        if let expiration = tokenExpiration, expiration > Date(), accessToken != nil {
            return
        }

        // Need to get new token
        try await refreshAccessToken()
    }

    private func refreshAccessToken() async throws {
        guard let url = URL(string: authURL) else {
            throw EbayError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Basic auth with client credentials
        let credentials = "\(clientId):\(clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw EbayError.authenticationFailed
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        // Request body for client credentials grant
        let body = "grant_type=client_credentials&scope=https://api.ebay.com/oauth/api_scope"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EbayError.authenticationFailed
        }

        let tokenResponse = try JSONDecoder().decode(EbayTokenResponse.self, from: data)

        accessToken = tokenResponse.accessToken
        tokenExpiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60)) // Refresh 1 min early
    }

    // MARK: - Data Processing

    private func processSalesData(_ response: EbaySearchResponse) -> EbayPriceData {
        guard let items = response.itemSummaries, !items.isEmpty else {
            return EbayPriceData(
                averagePrice: nil,
                lowestPrice: nil,
                highestPrice: nil,
                medianPrice: nil,
                recentSales: [],
                sampleSize: 0,
                lastUpdated: Date()
            )
        }

        // Extract prices
        let prices = items.compactMap { item -> Double? in
            guard let priceStr = item.price?.value else { return nil }
            return Double(priceStr)
        }.sorted()

        guard !prices.isEmpty else {
            return EbayPriceData(
                averagePrice: nil,
                lowestPrice: nil,
                highestPrice: nil,
                medianPrice: nil,
                recentSales: [],
                sampleSize: 0,
                lastUpdated: Date()
            )
        }

        // Calculate statistics
        let average = prices.reduce(0, +) / Double(prices.count)
        let lowest = prices.first
        let highest = prices.last
        let median = prices.count % 2 == 0
            ? (prices[prices.count/2 - 1] + prices[prices.count/2]) / 2
            : prices[prices.count/2]

        // Build recent sales list
        let recentSales = items.prefix(10).compactMap { item -> EbaySale? in
            guard let priceStr = item.price?.value,
                  let price = Double(priceStr) else { return nil }
            return EbaySale(
                title: item.title ?? "Unknown",
                price: price,
                currency: item.price?.currency ?? "USD",
                condition: item.condition ?? "Unknown",
                itemUrl: item.itemWebUrl,
                imageUrl: item.image?.imageUrl
            )
        }

        return EbayPriceData(
            averagePrice: average,
            lowestPrice: lowest,
            highestPrice: highest,
            medianPrice: median,
            recentSales: Array(recentSales),
            sampleSize: prices.count,
            lastUpdated: Date()
        )
    }
}

// MARK: - Models

struct EbayPriceData {
    let averagePrice: Double?
    let lowestPrice: Double?
    let highestPrice: Double?
    let medianPrice: Double?
    let recentSales: [EbaySale]
    let sampleSize: Int
    let lastUpdated: Date

    var formattedAveragePrice: String {
        guard let avg = averagePrice else { return "N/A" }
        return String(format: "$%.2f", avg)
    }

    var formattedPriceRange: String {
        guard let low = lowestPrice, let high = highestPrice else { return "N/A" }
        return String(format: "$%.2f - $%.2f", low, high)
    }
}

struct EbaySale {
    let title: String
    let price: Double
    let currency: String
    let condition: String
    let itemUrl: String?
    let imageUrl: String?

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }
}

// MARK: - API Response Models

struct EbaySearchResponse: Codable {
    let total: Int?
    let itemSummaries: [EbayItemSummary]?
}

struct EbayItemSummary: Codable {
    let itemId: String?
    let title: String?
    let price: EbayPrice?
    let condition: String?
    let itemWebUrl: String?
    let image: EbayImage?
}

struct EbayPrice: Codable {
    let value: String?
    let currency: String?
}

struct EbayImage: Codable {
    let imageUrl: String?
}

struct EbayTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Cache

private struct CachedPrice {
    let data: EbayPriceData
    let timestamp: Date

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 3600 // 1 hour
    }
}

// MARK: - Errors

enum EbayError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case apiError(statusCode: Int)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid eBay API URL"
        case .invalidResponse:
            return "Invalid response from eBay"
        case .authenticationFailed:
            return "Failed to authenticate with eBay"
        case .apiError(let code):
            return "eBay API error: \(code)"
        case .noResults:
            return "No results found on eBay"
        }
    }
}
