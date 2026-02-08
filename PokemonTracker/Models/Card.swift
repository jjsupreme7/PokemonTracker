import Foundation

// MARK: - Pokemon TCG API Response Models

struct PokemonTCGResponse: Codable {
    let data: [Card]
    let page: Int?
    let pageSize: Int?
    let count: Int?
    let totalCount: Int?
}

struct Card: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let supertype: String?
    let subtypes: [String]?
    let hp: String?
    let types: [String]?
    let evolvesFrom: String?
    let abilities: [Ability]?
    let attacks: [Attack]?
    let weaknesses: [TypeValue]?
    let resistances: [TypeValue]?
    let retreatCost: [String]?
    let convertedRetreatCost: Int?
    let set: CardSet
    let number: String
    let artist: String?
    let rarity: String?
    let flavorText: String?
    let nationalPokedexNumbers: [Int]?
    let legalities: Legalities?
    let images: CardImages
    let tcgplayer: TCGPlayer?
    let cardmarket: CardMarket?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.id == rhs.id
    }
}

struct Ability: Codable {
    let name: String
    let text: String
    let type: String
}

struct Attack: Codable {
    let name: String
    let cost: [String]?
    let convertedEnergyCost: Int?
    let damage: String?
    let text: String?
}

struct TypeValue: Codable {
    let type: String
    let value: String
}

struct CardSet: Codable {
    let id: String
    let name: String
    let series: String
    let printedTotal: Int?
    let total: Int?
    let legalities: Legalities?
    let ptcgoCode: String?
    let releaseDate: String?
    let updatedAt: String?
    let images: SetImages
}

struct SetImages: Codable {
    let symbol: String
    let logo: String
}

struct Legalities: Codable {
    let unlimited: String?
    let standard: String?
    let expanded: String?
}

struct CardImages: Codable {
    let small: String
    let large: String
}

struct TCGPlayer: Codable {
    let url: String?
    let updatedAt: String?
    let prices: TCGPlayerPrices?
}

struct TCGPlayerPrices: Codable {
    let holofoil: PriceData?
    let reverseHolofoil: PriceData?
    let normal: PriceData?
    let firstEditionHolofoil: PriceData?
    let firstEditionNormal: PriceData?

    enum CodingKeys: String, CodingKey {
        case holofoil
        case reverseHolofoil
        case normal
        case firstEditionHolofoil = "1stEditionHolofoil"
        case firstEditionNormal = "1stEditionNormal"
    }
}

struct PriceData: Codable {
    let low: Double?
    let mid: Double?
    let high: Double?
    let market: Double?
    let directLow: Double?
}

struct CardMarket: Codable {
    let url: String?
    let updatedAt: String?
    let prices: CardMarketPrices?
}

struct CardMarketPrices: Codable {
    let averageSellPrice: Double?
    let lowPrice: Double?
    let trendPrice: Double?
    let germanProLow: Double?
    let suggestedPrice: Double?
    let reverseHoloSell: Double?
    let reverseHoloLow: Double?
    let reverseHoloTrend: Double?
    let lowPriceExPlus: Double?
    let avg1: Double?
    let avg7: Double?
    let avg30: Double?
    let reverseHoloAvg1: Double?
    let reverseHoloAvg7: Double?
    let reverseHoloAvg30: Double?
}

// MARK: - Helper Extension

extension Card {
    /// Returns the best available market price
    var marketPrice: Double? {
        // Try TCGPlayer prices first
        if let tcgPrices = tcgplayer?.prices {
            return tcgPrices.holofoil?.market
                ?? tcgPrices.reverseHolofoil?.market
                ?? tcgPrices.normal?.market
                ?? tcgPrices.firstEditionHolofoil?.market
                ?? tcgPrices.firstEditionNormal?.market
        }

        // Fall back to CardMarket
        return cardmarket?.prices?.trendPrice
    }

    /// Formatted price string
    var formattedPrice: String {
        if let price = marketPrice {
            return String(format: "$%.2f", price)
        }
        return "N/A"
    }

    /// Full set identifier (e.g., "SV01 025/198")
    var setIdentifier: String {
        "\(set.id.uppercased()) \(number)/\(set.total ?? 0)"
    }
}
