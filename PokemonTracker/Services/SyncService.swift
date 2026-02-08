import Foundation
import SwiftData
import Supabase

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let supabase: SupabaseClient
    private var realtimeChannel: RealtimeChannelV2?

    private init() {
        supabase = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - Manual Sync

    func syncCollection(modelContext: ModelContext) async {
        guard AuthService.shared.isAuthenticated else { return }
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil

        do {
            // Get local cards that need syncing
            let descriptor = FetchDescriptor<CollectionCard>(
                predicate: #Predicate { $0.needsSync }
            )
            let localCards = try modelContext.fetch(descriptor)

            if localCards.isEmpty {
                // Just pull from server
                try await pullFromServer(modelContext: modelContext)
            } else {
                // Push local changes and handle conflicts
                try await pushAndPull(localCards: localCards, modelContext: modelContext)
            }

            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
            print("Sync error: \(error)")
        }

        isSyncing = false
    }

    private func pullFromServer(modelContext: ModelContext) async throws {
        let response = try await APIService.shared.getCollection()

        for serverCard in response.data {
            // Check if card exists locally
            let cardId = serverCard.cardId
            let descriptor = FetchDescriptor<CollectionCard>(
                predicate: #Predicate { $0.cardId == cardId }
            )

            if let existingCard = try modelContext.fetch(descriptor).first {
                // Update existing card
                updateLocalCard(existingCard, from: serverCard)
            } else {
                // Create new local card
                let newCard = createLocalCard(from: serverCard)
                modelContext.insert(newCard)
            }
        }

        try modelContext.save()
    }

    private func pushAndPull(localCards: [CollectionCard], modelContext: ModelContext) async throws {
        // Convert local cards to DTOs
        let dtos = localCards.map { card in
            CollectionCardDTO(
                cardId: card.cardId,
                name: card.name,
                setId: card.setId,
                setName: card.setName,
                number: card.number,
                rarity: card.rarity,
                imageSmall: card.imageSmall,
                imageLarge: card.imageLarge,
                quantity: card.quantity,
                purchasePrice: card.purchasePrice,
                currentPrice: card.currentPrice,
                dateAdded: ISO8601DateFormatter().string(from: card.dateAdded),
                updatedAt: ISO8601DateFormatter().string(from: card.updatedAt)
            )
        }

        // Sync with server
        let response = try await APIService.shared.syncCollection(cards: dtos)

        // Mark synced cards
        for card in localCards {
            card.needsSync = false
            card.lastSyncedAt = Date()
        }

        // Handle conflicts (server wins)
        for conflict in response.conflicts {
            let cardId = conflict.cardId
            let descriptor = FetchDescriptor<CollectionCard>(
                predicate: #Predicate { $0.cardId == cardId }
            )

            if let localCard = try modelContext.fetch(descriptor).first {
                updateLocalCard(localCard, from: conflict.serverVersion)
                localCard.needsSync = false
            }
        }

        // Pull any new cards from server
        try await pullFromServer(modelContext: modelContext)

        try modelContext.save()
    }

    private func updateLocalCard(_ local: CollectionCard, from server: ServerCollectionCard) {
        local.quantity = server.quantity
        local.purchasePrice = server.purchasePrice
        local.currentPrice = server.currentPrice
        local.serverId = UUID(uuidString: server.id)
        local.needsSync = false
        local.lastSyncedAt = Date()

        if let dateStr = ISO8601DateFormatter().date(from: server.updatedAt) {
            local.updatedAt = dateStr
        }
    }

    private func createLocalCard(from server: ServerCollectionCard) -> CollectionCard {
        let card = CollectionCard(
            cardId: server.cardId,
            name: server.name,
            setId: server.setId,
            setName: server.setName,
            number: server.number,
            rarity: server.rarity,
            imageSmall: server.imageSmall,
            imageLarge: server.imageLarge,
            quantity: server.quantity,
            purchasePrice: server.purchasePrice,
            currentPrice: server.currentPrice
        )
        card.serverId = UUID(uuidString: server.id)
        card.needsSync = false
        card.lastSyncedAt = Date()
        return card
    }

    // MARK: - Realtime Subscription

    func subscribeToChanges(userId: String, onUpdate: @escaping () -> Void) async {
        let channel = supabase.realtimeV2.channel("collection:\(userId)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "collection_cards",
            filter: "user_id=eq.\(userId)"
        )

        await channel.subscribe()

        Task {
            for await _ in changes {
                await MainActor.run {
                    onUpdate()
                }
            }
        }

        self.realtimeChannel = channel
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }
    }
}
