import Foundation

/// Service for interacting with the Pokemon TCG API
/// API Documentation: https://docs.pokemontcg.io/
actor PokemonTCGService {
    static let shared = PokemonTCGService()

    private let baseURL = "https://api.pokemontcg.io/v2"

    // OPTIONAL: Get a free API key at https://pokemontcg.io/ for higher rate limits
    // Without a key: 1000 requests/day, With key: 20,000 requests/day
    private let apiKey: String? = nil // Set your API key here if you have one

    private init() {}

    // MARK: - Search Cards

    /// Search for cards by name
    func searchCards(name: String, page: Int = 1, pageSize: Int = 20) async throws -> [Card] {
        let query = "name:\"\(name)*\""
        return try await fetchCards(query: query, page: page, pageSize: pageSize)
    }

    /// Search for cards by set ID and number (e.g., "sv1" and "25")
    func searchCard(setId: String, number: String) async throws -> Card? {
        let query = "set.id:\(setId) number:\(number)"
        let cards = try await fetchCards(query: query, page: 1, pageSize: 1)
        return cards.first
    }

    /// Search with a custom query string
    /// Query syntax: https://docs.pokemontcg.io/api-reference/cards/search-cards
    func searchCards(query: String, page: Int = 1, pageSize: Int = 20) async throws -> [Card] {
        return try await fetchCards(query: query, page: page, pageSize: pageSize)
    }

    // MARK: - Get Card by ID

    /// Get a specific card by its ID (e.g., "sv1-25")
    func getCard(id: String) async throws -> Card {
        let endpoint = "\(baseURL)/cards/\(id)"

        guard let url = URL(string: endpoint) else {
            throw PokemonTCGError.invalidURL
        }

        var request = URLRequest(url: url)
        addHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PokemonTCGError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PokemonTCGError.httpError(statusCode: httpResponse.statusCode)
        }

        struct SingleCardResponse: Codable {
            let data: Card
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(SingleCardResponse.self, from: data)
        return result.data
    }

    // MARK: - Get Sets

    /// Get all available sets
    func getSets() async throws -> [CardSet] {
        let endpoint = "\(baseURL)/sets"

        guard let url = URL(string: endpoint) else {
            throw PokemonTCGError.invalidURL
        }

        var request = URLRequest(url: url)
        addHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PokemonTCGError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PokemonTCGError.httpError(statusCode: httpResponse.statusCode)
        }

        struct SetsResponse: Codable {
            let data: [CardSet]
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(SetsResponse.self, from: data)
        return result.data
    }

    // MARK: - Private Helpers

    private func fetchCards(query: String, page: Int, pageSize: Int) async throws -> [Card] {
        var components = URLComponents(string: "\(baseURL)/cards")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "orderBy", value: "-set.releaseDate") // Newest first
        ]

        guard let url = components.url else {
            throw PokemonTCGError.invalidURL
        }

        var request = URLRequest(url: url)
        addHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PokemonTCGError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PokemonTCGError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(PokemonTCGResponse.self, from: data)
        return result.data
    }

    private func addHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }
    }
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
