import Foundation

enum Config {
    // MARK: - Supabase Configuration
    // Get these from your Supabase project settings
    static let supabaseURL = "https://twqjbatnqmytypfgewdn.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3cWpiYXRucW15dHlwZmdld2RuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxNDM2OTEsImV4cCI6MjA4NDcxOTY5MX0.Wffr39nIQLwsxTFiz6L8zcOaOjhjQ_5Oy9UJ2vdq-pc"

    // MARK: - Backend API
    // Your Node.js backend URL
    static let apiBaseURL = "http://localhost:3000"

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
    }
}
