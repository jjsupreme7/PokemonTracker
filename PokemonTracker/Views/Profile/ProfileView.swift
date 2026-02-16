import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var collection: [CollectionCard]
    @AppStorage("userName") private var userName = "Trainer"
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @AppStorage("showPriceChanges") private var showPriceChanges = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @ObservedObject var authService = AuthService.shared
    @ObservedObject var syncService = SyncService.shared
    @Environment(\.modelContext) private var modelContext

    @State private var showingEditName = false
    @State private var editedName = ""
    @State private var showSignOutAlert = false

    private var totalValue: Double {
        collection.reduce(0) { $0 + $1.totalValue }
    }

    private var totalCards: Int {
        collection.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    profileHeader

                    // Account Section (Sync & Alerts)
                    accountSection

                    // Stats Section
                    statsSection

                    // Settings Section
                    settingsSection

                    // About Section
                    aboutSection

                    // Sign Out
                    signOutButton
                }
                .padding()
            }
            .background(Color.pokemon.background)
            .navigationTitle("Profile")
            .preferredColorScheme(.dark)
            .alert("Edit Name", isPresented: $showingEditName) {
                TextField("Name", text: $editedName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    userName = editedName
                }
            } message: {
                Text("Enter your trainer name")
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pokemon.primary, Color.pokemon.primary.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text(String(userName.prefix(1)).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }

            // Name
            HStack(spacing: 8) {
                Text(userName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.pokemon.textPrimary)

                Button {
                    editedName = userName
                    showingEditName = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(Color.pokemon.primary)
                }
            }

            // Tier Badge
            HStack(spacing: 6) {
                Image(systemName: tierIcon)
                    .foregroundColor(tierColor)
                Text(tierName)
                    .font(.subheadline)
                    .foregroundColor(tierColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tierColor.opacity(0.2))
            .cornerRadius(20)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Tier Calculation

    private var tierName: String {
        switch totalValue {
        case 0..<100: return "Starter"
        case 100..<500: return "Bronze"
        case 500..<1000: return "Silver"
        case 1000..<5000: return "Gold"
        case 5000..<10000: return "Platinum"
        default: return "Diamond"
        }
    }

    private var tierIcon: String {
        switch totalValue {
        case 0..<100: return "star"
        case 100..<500: return "star.fill"
        case 500..<1000: return "star.circle"
        case 1000..<5000: return "star.circle.fill"
        case 5000..<10000: return "crown"
        default: return "crown.fill"
        }
    }

    private var tierColor: Color {
        switch totalValue {
        case 0..<100: return .gray
        case 100..<500: return Color(red: 205/255, green: 127/255, blue: 50/255) // Bronze
        case 500..<1000: return Color(red: 192/255, green: 192/255, blue: 192/255) // Silver
        case 1000..<5000: return Color(red: 255/255, green: 215/255, blue: 0/255) // Gold
        case 5000..<10000: return Color(red: 229/255, green: 228/255, blue: 226/255) // Platinum
        default: return Color(red: 185/255, green: 242/255, blue: 255/255) // Diamond
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collection Stats")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            VStack(spacing: 12) {
                StatRow(label: "Total Cards", value: "\(totalCards)", icon: "square.stack.fill")
                StatRow(label: "Unique Cards", value: "\(collection.count)", icon: "sparkles")
                StatRow(label: "Collection Value", value: String(format: "$%.2f", totalValue), icon: "dollarsign.circle.fill")

                // Progress to next tier
                let (nextTier, amountNeeded) = nextTierInfo
                if amountNeeded > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress to \(nextTier)")
                                .font(.caption)
                                .foregroundColor(Color.pokemon.textSecondary)
                            Spacer()
                            Text(String(format: "$%.0f to go", amountNeeded))
                                .font(.caption)
                                .foregroundColor(Color.pokemon.gold)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.pokemon.surface)
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.pokemon.gold)
                                    .frame(width: geometry.size.width * tierProgress, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
            .background(Color.pokemon.surface)
            .cornerRadius(12)
        }
    }

    private var nextTierInfo: (String, Double) {
        switch totalValue {
        case 0..<100: return ("Bronze", 100 - totalValue)
        case 100..<500: return ("Silver", 500 - totalValue)
        case 500..<1000: return ("Gold", 1000 - totalValue)
        case 1000..<5000: return ("Platinum", 5000 - totalValue)
        case 5000..<10000: return ("Diamond", 10000 - totalValue)
        default: return ("Max", 0)
        }
    }

    private var tierProgress: Double {
        switch totalValue {
        case 0..<100: return totalValue / 100
        case 100..<500: return (totalValue - 100) / 400
        case 500..<1000: return (totalValue - 500) / 500
        case 1000..<5000: return (totalValue - 1000) / 4000
        case 5000..<10000: return (totalValue - 5000) / 5000
        default: return 1.0
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            VStack(spacing: 0) {
                // Currency
                HStack {
                    Label("Currency", systemImage: "dollarsign.circle")
                        .foregroundColor(Color.pokemon.textPrimary)
                    Spacer()
                    Picker("Currency", selection: $selectedCurrency) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                        Text("JPY").tag("JPY")
                    }
                    .pickerStyle(.menu)
                    .tint(Color.pokemon.primary)
                }
                .padding()

                Divider()
                    .background(Color.pokemon.background)

                // Show Price Changes
                Toggle(isOn: $showPriceChanges) {
                    Label("Show Price Changes", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(Color.pokemon.textPrimary)
                }
                .tint(Color.pokemon.primary)
                .padding()
            }
            .background(Color.pokemon.surface)
            .cornerRadius(12)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            VStack(spacing: 0) {
                // Sync Status
                HStack {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(Color.pokemon.textPrimary)
                    Spacer()

                    if syncService.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let lastSync = syncService.lastSyncDate {
                        Text(lastSync.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(Color.pokemon.textSecondary)
                    } else {
                        Text("Not synced")
                            .font(.caption)
                            .foregroundColor(Color.pokemon.textSecondary)
                    }

                    Button(action: {
                        Task {
                            await syncService.syncCollection(modelContext: modelContext)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color.pokemon.primary)
                    }
                    .disabled(syncService.isSyncing)
                }
                .padding()

                Divider().background(Color.pokemon.background)

                // Price Alerts
                NavigationLink(destination: AlertsListView()) {
                    HStack {
                        Label("Price Alerts", systemImage: "bell.fill")
                            .foregroundColor(Color.pokemon.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.pokemon.textSecondary)
                    }
                    .padding()
                }

            }
            .background(Color.pokemon.surface)
            .cornerRadius(12)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .foregroundColor(Color.pokemon.textPrimary)

            VStack(spacing: 0) {
                AboutRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                Divider().background(Color.pokemon.background)
                AboutRow(label: "Data Source", value: "PokeTrace API")
                Divider().background(Color.pokemon.background)
                AboutRow(label: "Prices", value: "TCGPlayer + eBay")
            }
            .background(Color.pokemon.surface)
            .cornerRadius(12)
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button(action: { showSignOutAlert = true }) {
            HStack {
                Spacer()
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .background(Color.pokemon.surface)
            .cornerRadius(12)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authService.signOut()
                    hasCompletedOnboarding = false
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.pokemon.textPrimary)
        }
    }
}

// MARK: - About Row

struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textPrimary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(Color.pokemon.textSecondary)
        }
        .padding()
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: CollectionCard.self, inMemory: true)
}
