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
            HomeView()
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
        static let primary = Color(red: 45/255, green: 212/255, blue: 191/255)     // Teal green
        static let background = Color(red: 15/255, green: 23/255, blue: 42/255)    // Navy blue (dark)
        static let surface = Color(red: 30/255, green: 41/255, blue: 59/255)       // Navy blue (lighter)
        static let positive = Color(red: 34/255, green: 197/255, blue: 94/255)     // Green (keep)
        static let negative = Color(red: 239/255, green: 68/255, blue: 68/255)     // Red (keep)
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 148/255, green: 163/255, blue: 184/255) // Slate gray
    }

    // Alias for theme (used by new views)
    static var theme: pokemon.Type { pokemon.self }
}

#Preview {
    MainTabView()
}
