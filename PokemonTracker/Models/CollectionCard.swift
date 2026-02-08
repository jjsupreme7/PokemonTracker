import Foundation
import SwiftData

@Model
final class CollectionCard {
    var cardId: String
    var name: String
    var setId: String
    var setName: String
    var number: String
    var rarity: String?
    var imageSmall: String
    var imageLarge: String
    var quantity: Int
    var purchasePrice: Double?
    var purchaseDate: Date?
    var currentPrice: Double?
    var lastPriceUpdate: Date?
    var dateAdded: Date

    // MARK: - Sync Properties
    var serverId: UUID?        // Server-side UUID
    var needsSync: Bool        // True if changed locally and needs sync
    var lastSyncedAt: Date?    // Last successful sync timestamp
    var updatedAt: Date        // For conflict resolution

    init(
        cardId: String,
        name: String,
        setId: String,
        setName: String,
        number: String,
        rarity: String? = nil,
        imageSmall: String,
        imageLarge: String,
        quantity: Int = 1,
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        currentPrice: Double? = nil
    ) {
        self.cardId = cardId
        self.name = name
        self.setId = setId
        self.setName = setName
        self.number = number
        self.rarity = rarity
        self.imageSmall = imageSmall
        self.imageLarge = imageLarge
        self.quantity = quantity
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.currentPrice = currentPrice
        self.lastPriceUpdate = nil
        self.dateAdded = Date()

        // Sync defaults
        self.serverId = nil
        self.needsSync = true
        self.lastSyncedAt = nil
        self.updatedAt = Date()
    }

    /// Create from a Card API model
    convenience init(from card: Card, quantity: Int = 1, purchasePrice: Double? = nil) {
        self.init(
            cardId: card.id,
            name: card.name,
            setId: card.set.id,
            setName: card.set.name,
            number: card.number,
            rarity: card.rarity,
            imageSmall: card.images.small,
            imageLarge: card.images.large,
            quantity: quantity,
            purchasePrice: purchasePrice,
            purchaseDate: purchasePrice != nil ? Date() : nil,
            currentPrice: card.marketPrice
        )
    }
}

// MARK: - Computed Properties

extension CollectionCard {
    /// Total value of this card (quantity * current price)
    var totalValue: Double {
        guard let price = currentPrice else { return 0 }
        return price * Double(quantity)
    }

    /// Total cost basis (quantity * purchase price)
    var totalCost: Double? {
        guard let price = purchasePrice else { return nil }
        return price * Double(quantity)
    }

    /// Profit/Loss amount
    var profitLoss: Double? {
        guard let cost = totalCost else { return nil }
        return totalValue - cost
    }

    /// Profit/Loss percentage
    var profitLossPercent: Double? {
        guard let cost = totalCost, cost > 0 else { return nil }
        return ((totalValue - cost) / cost) * 100
    }

    /// Formatted current price
    var formattedPrice: String {
        if let price = currentPrice {
            return String(format: "$%.2f", price)
        }
        return "N/A"
    }

    /// Formatted total value
    var formattedTotalValue: String {
        String(format: "$%.2f", totalValue)
    }

    /// Formatted profit/loss
    var formattedProfitLoss: String? {
        guard let pl = profitLoss else { return nil }
        let sign = pl >= 0 ? "+" : ""
        return String(format: "%@$%.2f", sign, pl)
    }

    /// Formatted profit/loss percentage
    var formattedProfitLossPercent: String? {
        guard let plp = profitLossPercent else { return nil }
        let sign = plp >= 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, plp)
    }

    /// Set identifier string
    var setIdentifier: String {
        "\(setId.uppercased()) \(number)"
    }

    // MARK: - Sync Helpers

    /// Mark the card as synced with server
    func markAsSynced(serverId: UUID? = nil) {
        if let serverId = serverId {
            self.serverId = serverId
        }
        self.needsSync = false
        self.lastSyncedAt = Date()
    }

    /// Mark the card as needing sync (call after local changes)
    func markNeedsSync() {
        self.needsSync = true
        self.updatedAt = Date()
    }
}
