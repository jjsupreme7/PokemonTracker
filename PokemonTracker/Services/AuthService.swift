import Foundation
import CryptoKit
import Supabase

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case networkError(Error)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let message):
            return message
        }
    }
}

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    private let supabase: SupabaseClient

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    private init() {
        supabase = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )

        // Check for existing session
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    var accessToken: String? {
        get async {
            do {
                let session = try await supabase.auth.session
                return session.accessToken
            } catch {
                return nil
            }
        }
    }

    // MARK: - Username Auth (Simple Entry)

    func signInWithUsername(_ username: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let normalized = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let email = "\(normalized)@pokemontracker.app"
        let password = generatePassword(from: normalized)

        // Try sign in first (existing user)
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            self.currentUser = session.user
            self.isAuthenticated = true
            return
        } catch {
            // User doesn't exist, sign up instead
        }

        // Sign up new user
        let response = try await supabase.auth.signUp(email: email, password: password)
        let user = response.user

        // Update profile with username (profile auto-created by DB trigger)
        try await supabase
            .from("profiles")
            .update(["username": normalized, "display_name": username])
            .eq("id", value: user.id.uuidString)
            .execute()

        self.currentUser = user
        self.isAuthenticated = true
    }

    private func generatePassword(from username: String) -> String {
        let data = Data("pokemontracker_\(username)".utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Authentication

    func signUp(email: String, password: String, username: String? = nil) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            let user = response.user
            // Update profile with username (profile auto-created by trigger)
            if let username = username {
                try await supabase
                    .from("profiles")
                    .update([
                        "username": username,
                        "display_name": username
                    ])
                    .eq("id", value: user.id.uuidString)
                    .execute()
            }

            self.currentUser = user
            self.isAuthenticated = true
        } catch {
            throw AuthError.networkError(error)
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            throw AuthError.invalidCredentials
        }
    }

    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }

        try await supabase.auth.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    // MARK: - Profile

    func getProfile() async throws -> Profile? {
        guard let userId = currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        let response: Profile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return response
    }

    func updateProfile(username: String?, displayName: String?) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        var updates: [String: String] = [:]
        if let username = username {
            updates["username"] = username
        }
        if let displayName = displayName {
            updates["display_name"] = displayName
        }

        if !updates.isEmpty {
            try await supabase
                .from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .execute()
        }
    }
}

// MARK: - Profile Model

struct Profile: Codable {
    let id: String
    let username: String?
    let displayName: String?
    let tier: String
    let preferredCurrency: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, username, tier
        case displayName = "display_name"
        case preferredCurrency = "preferred_currency"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
