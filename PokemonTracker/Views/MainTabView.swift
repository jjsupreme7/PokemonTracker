import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject var authService = AuthService.shared

    var body: some View {
        Group {
            if authService.isAuthenticated {
                authenticatedView
            } else {
                LoginView()
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
