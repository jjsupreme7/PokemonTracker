import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case networkError(Error)
    case invalidResponse
    case serverError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        }
    }
}

actor APIService {
    static let shared = APIService()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private init() {}

    // MARK: - Generic Request

    private func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = await AuthService.shared.accessToken else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            let errorMessage = try? decoder.decode(ErrorResponse.self, from: data)
            throw APIError.serverError(httpResponse.statusCode, errorMessage?.error)
        }
    }

    private func requestNoContent(
        url: URL,
        method: String,
        body: Encodable? = nil
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }
    }

    // MARK: - Collection

    func getCollection(page: Int = 1, limit: Int = 50) async throws -> CollectionResponse {
        var components = URLComponents(url: Config.API.collection, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        return try await request(url: components.url!)
    }

    func addCard(_ card: CollectionCardDTO) async throws -> CollectionCardResponse {
        return try await request(url: Config.API.collection, method: "POST", body: card)
    }

    func updateCard(cardId: String, update: CollectionCardUpdate) async throws -> CollectionCardResponse {
        let url = Config.API.collection.appendingPathComponent("/\(cardId)")
        return try await request(url: url, method: "PUT", body: update)
    }

    func deleteCard(cardId: String) async throws {
        let url = Config.API.collection.appendingPathComponent("/\(cardId)")
        try await requestNoContent(url: url, method: "DELETE")
    }

    func syncCollection(cards: [CollectionCardDTO]) async throws -> SyncResponse {
        return try await request(
            url: Config.API.collectionSync,
            method: "POST",
            body: SyncRequest(cards: cards)
        )
    }

    // MARK: - Prices

    func getPrice(cardId: String) async throws -> PriceResponse {
        return try await request(url: Config.API.price(cardId: cardId), requiresAuth: false)
    }

    func getPriceHistory(cardId: String, days: Int = 30) async throws -> PriceHistoryResponse {
        var components = URLComponents(url: Config.API.priceHistory(cardId: cardId), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "days", value: "\(days)")]
        return try await request(url: components.url!, requiresAuth: false)
    }

    // MARK: - Alerts

    func getAlerts(activeOnly: Bool = false) async throws -> AlertsResponse {
        var components = URLComponents(url: Config.API.alerts, resolvingAgainstBaseURL: false)!
        if activeOnly {
            components.queryItems = [URLQueryItem(name: "active", value: "true")]
        }
        return try await request(url: components.url!)
    }

    func createAlert(_ alert: CreateAlertRequest) async throws -> AlertResponse {
        return try await request(url: Config.API.alerts, method: "POST", body: alert)
    }

    func deleteAlert(id: String) async throws {
        try await requestNoContent(url: Config.API.alert(id: id), method: "DELETE")
    }

    // MARK: - Market Movers

    func getMarketMovers() async throws -> MarketMoversResponse {
        return try await request(url: Config.API.marketMovers, requiresAuth: false)
    }

    // MARK: - Devices

    func registerDevice(token: String, platform: String = "ios") async throws {
        let body = RegisterDeviceRequest(token: token, platform: platform)
        let _: DeviceResponse = try await request(
            url: Config.API.registerDevice,
            method: "POST",
            body: body
        )
    }
}

// MARK: - Request/Response Types

struct ErrorResponse: Codable {
    let error: String
}

// Collection
struct CollectionResponse: Codable {
    let data: [ServerCollectionCard]
    let pagination: Pagination
}

struct ServerCollectionCard: Codable {
    let id: String
    let userId: String
    let cardId: String
    let name: String
    let setId: String
    let setName: String
    let number: String
    let rarity: String?
    let imageSmall: String
    let imageLarge: String
    let quantity: Int
    let purchasePrice: Double?
    let currentPrice: Double?
    let dateAdded: String
    let updatedAt: String
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int?
    let totalPages: Int
}

struct CollectionCardDTO: Codable {
    let cardId: String
    let name: String
    let setId: String
    let setName: String
    let number: String
    let rarity: String?
    let imageSmall: String
    let imageLarge: String
    let quantity: Int
    let purchasePrice: Double?
    let currentPrice: Double?
    let dateAdded: String?
    let updatedAt: String?
}

struct CollectionCardUpdate: Codable {
    let quantity: Int?
    let purchasePrice: Double?
    let currentPrice: Double?
}

struct CollectionCardResponse: Codable {
    let data: ServerCollectionCard
    let merged: Bool?
}

struct SyncRequest: Codable {
    let cards: [CollectionCardDTO]
}

struct SyncResponse: Codable {
    let inserted: Int
    let updated: Int
    let conflicts: [SyncConflict]
}

struct SyncConflict: Codable {
    let cardId: String
    let serverVersion: ServerCollectionCard
}

// Prices
struct PriceResponse: Codable {
    let cardId: String
    let price: Double
    let source: String
    let recordedAt: String
    let fresh: Bool
}

struct PriceHistoryResponse: Codable {
    let cardId: String
    let history: [PricePoint]
    let stats: PriceStats?
}

struct PricePoint: Codable {
    let price: Double
    let priceSource: String
    let recordedAt: String
}

struct PriceStats: Codable {
    let current: Double
    let min: Double
    let max: Double
    let avg: Double
    let change: Double
}

// Alerts
struct AlertsResponse: Codable {
    let data: [ServerPriceAlert]
}

struct ServerPriceAlert: Codable, Identifiable {
    let id: String
    let userId: String
    let cardId: String
    let cardName: String
    let targetPrice: Double
    let alertType: String
    let isActive: Bool
    let triggeredAt: String?
    let createdAt: String
}

struct CreateAlertRequest: Codable {
    let cardId: String
    let cardName: String
    let targetPrice: Double
    let alertType: String
}

struct AlertResponse: Codable {
    let data: ServerPriceAlert
}

// Devices
struct RegisterDeviceRequest: Codable {
    let token: String
    let platform: String
}

struct DeviceResponse: Codable {
    let data: DeviceToken
}

struct DeviceToken: Codable {
    let id: String
    let userId: String
    let token: String
    let platform: String
    let isActive: Bool
    let createdAt: String
}

// Market Movers
struct MarketMoversResponse: Codable {
    let gainers: [MarketMoverCard]
    let losers: [MarketMoverCard]
    let hotCards: [MarketMoverCard]
    let cachedAt: String
}

struct MarketMoverCard: Codable, Identifiable {
    let cardId: String
    let name: String
    let setName: String
    let rarity: String?
    let imageSmall: String
    let imageLarge: String
    let currentPrice: Double?
    let previousPrice: Double?
    let priceChange: Double?
    let priceChangePercent: Double?
    let trackerCount: Int?

    var id: String { cardId }
}
