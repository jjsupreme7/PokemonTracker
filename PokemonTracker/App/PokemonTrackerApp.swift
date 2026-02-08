import SwiftUI
import SwiftData

@main
struct PokemonTrackerApp: App {
    // Connect AppDelegate for push notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CollectionCard.self,
            PriceHistory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onReceive(NotificationCenter.default.publisher(for: .navigateToCard)) { notification in
                    // Handle navigation to card from push notification
                    if let cardId = notification.userInfo?["cardId"] as? String {
                        print("Navigate to card: \(cardId)")
                        // TODO: Implement deep linking to card detail
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
