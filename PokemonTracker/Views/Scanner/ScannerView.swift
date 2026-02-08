import SwiftUI
import AVFoundation

struct ScannerView: View {
    @StateObject private var scannerService = CardScannerService()
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var scanResult: ScanResult?
    @State private var errorMessage: String?
    @State private var showingResults = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showingResults {
                    resultsView
                } else {
                    scannerContent
                }
            }
            .background(Color.pokemon.background)
            .navigationTitle("Card Scanner")
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    Task {
                        await processImage(image)
                    }
                }
            }
        }
    }

    // MARK: - Scanner Content

    private var scannerContent: some View {
        VStack(spacing: 24) {
            // Info Card
            infoCard

            // Scanner Area
            scannerArea

            // Tips
            tipsSection

            Spacer()

            // Action Buttons
            actionButtons
        }
        .padding()
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.title)
                .foregroundColor(Color.pokemon.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Scan Pokemon Cards")
                    .font(.headline)
                    .foregroundColor(Color.pokemon.textPrimary)

                Text("Take a photo or upload an image of your card")
                    .font(.caption)
                    .foregroundColor(Color.pokemon.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.pokemon.surface)
        .cornerRadius(12)
    }

    // MARK: - Scanner Area

    private var scannerArea: some View {
        ZStack {
            // Card outline
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    Color.pokemon.primary,
                    style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                )
                .aspectRatio(0.714, contentMode: .fit) // Standard card ratio

            if isProcessing {
                // Processing overlay
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color.pokemon.primary)

                    Text("Analyzing card...")
                        .font(.subheadline)
                        .foregroundColor(Color.pokemon.textSecondary)
                }
            } else if let error = errorMessage {
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color.pokemon.negative)

                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(Color.pokemon.textSecondary)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        resetScanner()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.pokemon.primary)
                }
                .padding()
            } else {
                // Default state
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color.pokemon.primary.opacity(0.5))

                    Text("Position card here")
                        .font(.subheadline)
                        .foregroundColor(Color.pokemon.textSecondary)
                }
            }
        }
        .frame(maxWidth: 250)
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tips for best results:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color.pokemon.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                TipRow(icon: "sun.max", text: "Good lighting helps accuracy")
                TipRow(icon: "rectangle.portrait", text: "Keep the card flat and centered")
                TipRow(icon: "eye", text: "Make sure card name is visible")
            }
        }
        .padding()
        .background(Color.pokemon.surface.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Take Photo Button
            Button {
                showingImagePicker = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Photo")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pokemon.primary)
                .cornerRadius(12)
            }
            .disabled(isProcessing)

            // Upload Button
            Button {
                showingImagePicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Upload")
                }
                .font(.headline)
                .foregroundColor(Color.pokemon.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pokemon.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pokemon.primary, lineWidth: 1)
                )
                .cornerRadius(12)
            }
            .disabled(isProcessing)
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button {
                    resetScanner()
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Scan Again")
                    }
                    .foregroundColor(Color.pokemon.primary)
                }

                Spacer()
            }

            // Confidence Badge
            if let result = scanResult {
                confidenceBadge(for: result)
            }

            if let result = scanResult, result.cards.isEmpty {
                // No matches found
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(Color.pokemon.textSecondary)

                    Text("No Cards Found")
                        .font(.headline)
                        .foregroundColor(Color.pokemon.textPrimary)

                    Text("Try scanning the card again with better lighting or a clearer image.")
                        .font(.subheadline)
                        .foregroundColor(Color.pokemon.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else if let result = scanResult {
                // Show matched cards
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select the matching card:")
                        .font(.headline)
                        .foregroundColor(Color.pokemon.textPrimary)

                    Text(result.matchType.reliability)
                        .font(.caption)
                        .foregroundColor(Color.pokemon.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(result.cards) { card in
                            NavigationLink(destination: CardDetailView(card: card)) {
                                SearchResultRow(card: card)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Confidence Badge

    private func confidenceBadge(for result: ScanResult) -> some View {
        VStack(spacing: 12) {
            // Confidence circle
            ZStack {
                Circle()
                    .stroke(Color.pokemon.surface, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(result.overallConfidence))
                    .stroke(confidenceColor(for: result.overallConfidence), lineWidth: 8)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(result.confidencePercent)%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color.pokemon.textPrimary)
                }
            }

            // Match type badge
            HStack(spacing: 6) {
                Image(systemName: matchTypeIcon(for: result.matchType))
                    .font(.caption)
                Text(result.matchType.description)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(confidenceColor(for: result.overallConfidence))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(confidenceColor(for: result.overallConfidence).opacity(0.2))
            .cornerRadius(12)

            // Recognized text
            Text("Detected: \(result.identifier.description)")
                .font(.caption2)
                .foregroundColor(Color.pokemon.textSecondary)
        }
        .padding()
        .background(Color.pokemon.surface)
        .cornerRadius(16)
    }

    private func confidenceColor(for confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0: return Color.pokemon.positive
        case 0.6..<0.8: return Color.pokemon.primary
        case 0.4..<0.6: return .orange
        default: return Color.pokemon.negative
        }
    }

    private func matchTypeIcon(for type: ScanResult.MatchType) -> String {
        switch type {
        case .exact: return "checkmark.seal.fill"
        case .setAndName: return "checkmark.circle.fill"
        case .nameOnly: return "questionmark.circle.fill"
        }
    }

    // MARK: - Process Image

    private func processImage(_ image: UIImage) async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }

        do {
            // Step 1: Recognize text with confidence scores
            let recognizedTexts = try await scannerService.recognizeText(from: image)

            guard !recognizedTexts.isEmpty else {
                throw ScannerError.noTextFound
            }

            // Step 2: Parse card identifiers with confidence
            guard let identifier = scannerService.parseCardIdentifiers(from: recognizedTexts) else {
                throw ScannerError.cardNotFound
            }

            // Step 3: Search for matching cards and get result with confidence
            let result = try await scannerService.findCard(from: identifier)

            await MainActor.run {
                scanResult = result
                isProcessing = false
                showingResults = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    // MARK: - Reset Scanner

    private func resetScanner() {
        selectedImage = nil
        scanResult = nil
        errorMessage = nil
        showingResults = false
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color.pokemon.primary)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(Color.pokemon.textSecondary)
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        // Try to use camera, fall back to photo library
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ScannerView()
}
