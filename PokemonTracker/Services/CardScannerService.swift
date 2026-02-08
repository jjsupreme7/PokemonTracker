import Foundation
import Vision
import UIKit

/// Service for scanning and recognizing Pokemon cards using Vision framework
class CardScannerService: ObservableObject {
    @Published var recognizedText: [String] = []
    @Published var isProcessing = false
    @Published var error: Error?

    /// Process an image and extract text with confidence scores
    func recognizeText(from image: UIImage) async throws -> [RecognizedText] {
        guard let cgImage = image.cgImage else {
            throw ScannerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let recognizedStrings = observations.compactMap { observation -> RecognizedText? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedText(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: recognizedStrings)
            }

            // Configure for better accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Simple text recognition (backward compatible)
    func recognizeTextStrings(from image: UIImage) async throws -> [String] {
        let results = try await recognizeText(from: image)
        return results.map { $0.text }
    }

    /// Parse recognized text to extract card identifiers with confidence
    func parseCardIdentifiers(from recognizedTexts: [RecognizedText]) -> CardIdentifier? {
        var cardName: String?
        var cardNameConfidence: Float = 0
        var setNumber: String?
        var setNumberConfidence: Float = 0
        var setCode: String?
        var setCodeConfidence: Float = 0

        for recognized in recognizedTexts {
            let text = recognized.text

            // Look for set number pattern like "025/198" or "25/198"
            if let match = text.range(of: #"\d{1,3}/\d{1,3}"#, options: .regularExpression) {
                setNumber = String(text[match])
                setNumberConfidence = recognized.confidence
            }

            // Look for set code patterns like "SV01", "SWSH", "XY", etc.
            if let match = text.range(of: #"[A-Z]{2,4}\d{0,2}"#, options: .regularExpression) {
                let potential = String(text[match])
                // Filter out common false positives
                if !["HP", "LV", "EX", "GX", "VMAX", "VSTAR"].contains(potential) {
                    setCode = potential.lowercased()
                    setCodeConfidence = recognized.confidence
                }
            }

            // The card name is usually one of the first recognizable strings
            if cardName == nil {
                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanText.count >= 3 &&
                   cleanText.count <= 30 &&
                   !cleanText.contains("/") &&
                   !cleanText.allSatisfy({ $0.isNumber }) {
                    // Check if it looks like a Pokemon name
                    if cleanText.first?.isUppercase == true {
                        cardName = cleanText
                        cardNameConfidence = recognized.confidence
                    }
                }
            }
        }

        // We need at least a name or a set number to search
        guard cardName != nil || setNumber != nil else {
            return nil
        }

        // Calculate overall confidence
        var confidenceFactors: [Float] = []
        if cardName != nil { confidenceFactors.append(cardNameConfidence) }
        if setNumber != nil { confidenceFactors.append(setNumberConfidence * 1.5) } // Weight set number higher
        if setCode != nil { confidenceFactors.append(setCodeConfidence * 1.3) }

        let averageConfidence = confidenceFactors.reduce(0, +) / Float(confidenceFactors.count)
        let overallConfidence = min(averageConfidence, 1.0)

        return CardIdentifier(
            name: cardName,
            setNumber: setNumber?.components(separatedBy: "/").first,
            setCode: setCode,
            confidence: overallConfidence
        )
    }

    /// Parse from simple string array (backward compatible)
    func parseCardIdentifiers(from texts: [String]) -> CardIdentifier? {
        let recognized = texts.map { RecognizedText(text: $0, confidence: 0.8, boundingBox: .zero) }
        return parseCardIdentifiers(from: recognized)
    }

    /// Search for a card based on scanned identifiers
    func findCard(from identifier: CardIdentifier) async throws -> ScanResult {
        let service = PokemonTCGService.shared
        var cards: [Card] = []
        var matchType: ScanResult.MatchType = .nameOnly

        // If we have a set code and number, try exact match first
        if let setCode = identifier.setCode, let number = identifier.setNumber {
            if let exactMatch = try await service.searchCard(setId: setCode, number: number) {
                cards = [exactMatch]
                matchType = .exact
            }
        }

        // Fall back to name search
        if cards.isEmpty, let name = identifier.name {
            cards = try await service.searchCards(name: name, pageSize: 10)
            matchType = identifier.setCode != nil ? .setAndName : .nameOnly
        }

        return ScanResult(
            identifier: identifier,
            cards: cards,
            matchType: matchType
        )
    }
}

// MARK: - Supporting Types

/// Text recognized from the image with confidence score
struct RecognizedText {
    let text: String
    let confidence: Float // 0.0 to 1.0
    let boundingBox: CGRect
}

/// Parsed card identifiers from OCR
struct CardIdentifier {
    let name: String?
    let setNumber: String?
    let setCode: String?
    let confidence: Float // Overall OCR confidence

    init(name: String?, setNumber: String?, setCode: String?, confidence: Float = 0.8) {
        self.name = name
        self.setNumber = setNumber
        self.setCode = setCode
        self.confidence = confidence
    }

    var description: String {
        var parts: [String] = []
        if let name = name { parts.append("Name: \(name)") }
        if let setCode = setCode { parts.append("Set: \(setCode)") }
        if let number = setNumber { parts.append("Number: \(number)") }
        return parts.joined(separator: ", ")
    }

    /// Confidence level description
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.9...1.0: return .veryHigh
        case 0.75..<0.9: return .high
        case 0.5..<0.75: return .medium
        default: return .low
        }
    }

    enum ConfidenceLevel: String {
        case veryHigh = "Very High"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: String {
            switch self {
            case .veryHigh, .high: return "positive"
            case .medium: return "primary"
            case .low: return "negative"
            }
        }
    }
}

/// Result of a card scan operation
struct ScanResult {
    let identifier: CardIdentifier
    let cards: [Card]
    let matchType: MatchType

    enum MatchType {
        case exact       // Matched by set code + number (most reliable)
        case setAndName  // Matched by set + name
        case nameOnly    // Matched by name only (least reliable, may have variants)

        var description: String {
            switch self {
            case .exact: return "Exact Match"
            case .setAndName: return "Set Match"
            case .nameOnly: return "Name Match"
            }
        }

        var reliability: String {
            switch self {
            case .exact: return "This is the exact card"
            case .setAndName: return "Matched by set, verify the variant"
            case .nameOnly: return "Multiple variants may exist"
            }
        }
    }

    /// Overall confidence combining OCR and match type
    var overallConfidence: Float {
        let matchMultiplier: Float = switch matchType {
        case .exact: 1.0
        case .setAndName: 0.85
        case .nameOnly: 0.6
        }
        return identifier.confidence * matchMultiplier
    }

    var confidencePercent: Int {
        Int(overallConfidence * 100)
    }
}

enum ScannerError: LocalizedError {
    case invalidImage
    case noTextFound
    case cardNotFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .noTextFound:
            return "No text found in the image"
        case .cardNotFound:
            return "Could not identify the card"
        }
    }
}
