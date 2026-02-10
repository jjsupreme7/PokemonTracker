import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var deepLinkCard: Card?
    @State private var isLoadingDeepLink = false
    @ObservedObject var authService = AuthService.shared

    var body: some View {
        Group {
            if authService.isAuthenticated {
                authenticatedView
            } else {
                LoginView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCard)) { notification in
            if let cardId = notification.userInfo?["cardId"] as? String {
                Task {
                    await navigateToCard(id: cardId)
                }
            }
        }
        .fullScreenCover(item: $deepLinkCard) { card in
            NavigationStack {
                CardDetailView(card: card)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                deepLinkCard = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.pokemon.textSecondary)
                            }
                        }
                    }
            }
        }
    }

    private var authenticatedView: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(1)

            ScannerView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Scan")
                }
                .tag(2)

            PortfolioView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Portfolio")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .tint(Color.pokemon.primary)
    }

    private func navigateToCard(id: String) async {
        isLoadingDeepLink = true
        do {
            let card = try await PokemonTCGService.shared.getCard(id: id)
            await MainActor.run {
                selectedTab = 1
                deepLinkCard = card
                isLoadingDeepLink = false
            }
        } catch {
            print("Deep link failed to load card \(id): \(error)")
            isLoadingDeepLink = false
        }
    }
}

// MARK: - App Color Theme

extension Color {
    struct pokemon {
        static let primary = Color(red: 220/255, green: 38/255, blue: 38/255)      // Pokemon Red
        static let gold = Color(red: 250/255, green: 204/255, blue: 21/255)        // Pikachu Gold
        static let background = Color(red: 11/255, green: 14/255, blue: 26/255)    // Deep indigo
        static let surface = Color(red: 18/255, green: 22/255, blue: 41/255)       // Warm surface
        static let surfaceHover = Color(red: 26/255, green: 31/255, blue: 58/255)  // Hover surface
        static let positive = Color(red: 74/255, green: 222/255, blue: 128/255)    // Bright green
        static let negative = Color(red: 248/255, green: 113/255, blue: 113/255)   // Light red (errors)
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 139/255, green: 146/255, blue: 179/255) // Warm indigo gray
    }

    // Alias for theme (used by new views)
    static var theme: pokemon.Type { pokemon.self }
}

#Preview {
    MainTabView()
}
