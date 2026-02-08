# Pokemon Tracker

A SwiftUI iOS app for tracking your Pokemon TCG collection with card scanning and price tracking.

## Features

- **Card Scanner**: Scan Pokemon cards using your camera to identify them
- **Portfolio Tracking**: Track your collection value and profit/loss
- **Price Data**: Real-time pricing from TCGPlayer via Pokemon TCG API
- **Search**: Search the entire Pokemon TCG database

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Physical device for camera scanning (simulator won't work for camera)

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select "App" under iOS
4. Configure:
   - Product Name: `PokemonTracker`
   - Team: Your Apple Developer Team
   - Organization Identifier: `com.yourname` (or your identifier)
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData ✓
5. Save to `~/Desktop/PokemonTracker/`

### 2. Add Source Files

After creating the project, add the source files from the `PokemonTracker/` folder:

1. In Xcode, right-click on the `PokemonTracker` folder in the navigator
2. Select "Add Files to PokemonTracker..."
3. Navigate to `~/Desktop/PokemonTracker/PokemonTracker/`
4. Select all folders (App, Models, Views, Services, Storage, Utilities)
5. Make sure "Copy items if needed" is checked
6. Click Add

### 3. Configure Permissions

Add these to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan your Pokemon cards</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to scan cards from your photos</string>
```

Or in Xcode:
1. Select the project in navigator
2. Select the target
3. Go to "Info" tab
4. Add:
   - Privacy - Camera Usage Description
   - Privacy - Photo Library Usage Description

### 4. (Optional) Add API Key

For higher rate limits (20,000 requests/day vs 1,000), get a free API key:

1. Go to https://pokemontcg.io/
2. Click "Get Started"
3. Create an account and get your API key
4. Add it in `Services/PokemonTCGService.swift`:

```swift
private let apiKey: String? = "YOUR_API_KEY_HERE"
```

### 5. Run the App

1. Connect your iPhone or select a simulator
2. Press Cmd+R or click the Play button
3. The app should build and run

**Note**: Camera scanning requires a physical device. The simulator will use the photo library instead.

## Project Structure

```
PokemonTracker/
├── App/
│   └── PokemonTrackerApp.swift      # App entry point
├── Models/
│   ├── Card.swift                   # Pokemon TCG API models
│   ├── CollectionCard.swift         # SwiftData collection model
│   └── PriceHistory.swift           # Price history model
├── Views/
│   ├── MainTabView.swift            # Tab navigation
│   ├── Home/
│   │   └── HomeView.swift           # Home dashboard
│   ├── Scanner/
│   │   └── ScannerView.swift        # Card scanner
│   ├── Portfolio/
│   │   └── PortfolioView.swift      # Collection view
│   └── Search/
│       ├── SearchView.swift         # Card search
│       └── CardDetailView.swift     # Card details
├── Services/
│   ├── PokemonTCGService.swift      # Pokemon TCG API client
│   └── CardScannerService.swift     # Vision framework scanner
├── Storage/
│   └── (SwiftData handled by models)
└── Utilities/
    └── Extensions.swift             # Helper extensions
```

## APIs Used

- **Pokemon TCG API** (https://pokemontcg.io/) - Card database and images
- Pricing data comes from TCGPlayer via the Pokemon TCG API

## Color Theme

The app uses a dark theme inspired by GuardianTCG:

- Background: #0D0D1A
- Surface: #1E1E2E
- Primary: #8B5CF6 (Purple)
- Positive: #22C55E (Green)
- Negative: #EF4444 (Red)

## Future Improvements

- [ ] Price history charts with Swift Charts
- [ ] Cloud sync with CloudKit
- [ ] Barcode scanning for sealed products
- [ ] Social features (sharing, leaderboards)
- [ ] Push notifications for price alerts

## Troubleshooting

### "No cards found" when scanning
- Ensure good lighting
- Keep the card flat and centered
- Make sure the card name/number is visible
- Try taking a clearer photo

### API rate limits
- Free tier: 1,000 requests/day
- With API key: 20,000 requests/day
- The app caches results to minimize API calls

### Camera not working
- Camera only works on physical devices
- Check that camera permissions are granted in Settings

## License

This project is for educational purposes.
