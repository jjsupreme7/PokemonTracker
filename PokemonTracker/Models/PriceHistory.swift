import Foundation
import SwiftData

@Model
final class PriceHistory {
    var cardId: String
    var price: Double
    var date: Date

    init(cardId: String, price: Double, date: Date = Date()) {
        self.cardId = cardId
        self.price = price
        self.date = date
    }
}

// MARK: - Price History Helpers

extension PriceHistory {
    /// Get price change between two price history entries
    static func priceChange(from older: PriceHistory, to newer: PriceHistory) -> (amount: Double, percent: Double) {
        let amount = newer.price - older.price
        let percent = older.price > 0 ? (amount / older.price) * 100 : 0
        return (amount, percent)
    }
}

// MARK: - Chart Data Point

struct PriceChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}
