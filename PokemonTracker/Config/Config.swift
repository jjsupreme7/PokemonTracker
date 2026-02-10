import Foundation

enum Config {
    // MARK: - Supabase Configuration
    // Get these from your Supabase project settings
    static let supabaseURL = "https://gajvwzfrltmlxtuidika.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdhanZ3emZybHRtbHh0dWlkaWthIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1NzUzMjMsImV4cCI6MjA4NjE1MTMyM30.dVlJ3ou2PDtd0ZYh94M7h8ECA7wyQV1O6JiCdXtc4cg"

    // MARK: - PokeTrace API (pricing from eBay, TCGPlayer, CardMarket)
    static let poketraceAPIKey = "pc_db7f153add976df4f5e7bc490c3cb1e8b37de8339b60861e"
    static let poketraceBaseURL = "https://api.poketrace.com/v1"

    // MARK: - Backend API
    // Your Node.js backend URL
    static let apiBaseURL = "https://pokemontracker-production.up.railway.app"

    // MARK: - Environment
    #if DEBUG
    static let environment = "development"
    static let isDebug = true
    #else
    static let environment = "production"
    static let isDebug = false
    #endif

    // MARK: - API Endpoints
    enum API {
        static var baseURL: URL { URL(string: apiBaseURL)! }

        // Auth
        static var register: URL { baseURL.appendingPathComponent("/api/auth/register") }
        static var login: URL { baseURL.appendingPathComponent("/api/auth/login") }
        static var logout: URL { baseURL.appendingPathComponent("/api/auth/logout") }

        // Collection
        static var collection: URL { baseURL.appendingPathComponent("/api/collection") }
        static var collectionSync: URL { baseURL.appendingPathComponent("/api/collection/sync") }

        // Prices
        static func price(cardId: String) -> URL {
            baseURL.appendingPathComponent("/api/prices/\(cardId)")
        }
        static func priceHistory(cardId: String) -> URL {
            baseURL.appendingPathComponent("/api/prices/\(cardId)/history")
        }

        // Alerts
        static var alerts: URL { baseURL.appendingPathComponent("/api/alerts") }
        static func alert(id: String) -> URL {
            baseURL.appendingPathComponent("/api/alerts/\(id)")
        }

        // Devices
        static var registerDevice: URL { baseURL.appendingPathComponent("/api/devices/register") }

        // Scanner
        static var scanIdentify: URL { baseURL.appendingPathComponent("/api/scan/identify") }

        // Market Movers
        static var marketMovers: URL { baseURL.appendingPathComponent("/api/market-movers") }
    }
}
