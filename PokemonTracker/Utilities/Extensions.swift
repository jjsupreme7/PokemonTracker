import SwiftUI

// MARK: - View Extensions

extension View {
    /// Apply a card-style background
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.pokemon.surface)
            .cornerRadius(12)
    }

    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format date for display
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }

    /// Relative time string (e.g., "2 hours ago")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Double Extensions

extension Double {
    /// Format as currency
    var asCurrency: String {
        String(format: "$%.2f", self)
    }

    /// Format as percentage
    var asPercentage: String {
        String(format: "%.1f%%", self)
    }

    /// Format as percentage with sign
    var asSignedPercentage: String {
        let sign = self >= 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, self)
    }
}

// MARK: - String Extensions

extension String {
    /// Check if string contains only digits
    var isNumeric: Bool {
        !isEmpty && allSatisfy { $0.isNumber }
    }

    /// Extract numbers from string
    var extractedNumbers: String {
        filter { $0.isNumber }
    }
}

// MARK: - Array Extensions

extension Array where Element == String {
    /// Join with comma separator
    var commaSeparated: String {
        joined(separator: ", ")
    }
}
