import SwiftUI

struct AlertsListView: View {
    @State private var alerts: [ServerPriceAlert] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateAlert = false

    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .theme.primary))
            } else if alerts.isEmpty {
                emptyState
            } else {
                alertsList
            }
        }
        .navigationTitle("Price Alerts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateAlert = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(.theme.primary)
                }
            }
        }
        .sheet(isPresented: $showCreateAlert) {
            CreateAlertView(onCreated: loadAlerts)
        }
        .task {
            await loadAlerts()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(.theme.textSecondary)

            Text("No Price Alerts")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.theme.textPrimary)

            Text("Create alerts to get notified when card prices reach your target")
                .font(.subheadline)
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showCreateAlert = true }) {
                Text("Create Alert")
                    .fontWeight(.semibold)
                    .frame(width: 160, height: 44)
                    .background(Color.theme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
    }

    private var alertsList: some View {
        List {
            ForEach(alerts) { alert in
                AlertRowView(alert: alert, onDelete: {
                    await deleteAlert(alert)
                })
            }
            .listRowBackground(Color.theme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadAlerts()
        }
    }

    private func loadAlerts() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.getAlerts()
            alerts = response.data
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func deleteAlert(_ alert: ServerPriceAlert) async {
        do {
            try await APIService.shared.deleteAlert(id: alert.id)
            alerts.removeAll { $0.id == alert.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Alert Row View

struct AlertRowView: View {
    let alert: ServerPriceAlert
    let onDelete: () async -> Void

    @State private var isDeleting = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(alert.isActive ? Color.theme.primary.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: alert.alertType == "above" ? "arrow.up.circle" : "arrow.down.circle")
                    .font(.title2)
                    .foregroundColor(alert.isActive ? .theme.primary : .gray)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.cardName)
                    .font(.headline)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(alert.alertType == "above" ? "Above" : "Below")
                        .foregroundColor(.theme.textSecondary)
                    Text("$\(alert.targetPrice, specifier: "%.2f")")
                        .foregroundColor(.theme.primary)
                        .fontWeight(.medium)
                }
                .font(.subheadline)

                if !alert.isActive {
                    Text("Triggered")
                        .font(.caption)
                        .foregroundColor(.theme.positive)
                }
            }

            Spacer()

            // Delete button
            Button(action: {
                Task {
                    isDeleting = true
                    await onDelete()
                    isDeleting = false
                }
            }) {
                if isDeleting {
                    ProgressView()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "trash")
                        .foregroundColor(.theme.negative)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Create Alert View

struct CreateAlertView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: () async -> Void

    @State private var cardId = ""
    @State private var cardName = ""
    @State private var targetPrice = ""
    @State private var alertType: AlertType = .below
    @State private var isCreating = false
    @State private var errorMessage: String?

    enum AlertType: String, CaseIterable {
        case above
        case below

        var title: String {
            switch self {
            case .above: return "Price goes above"
            case .below: return "Price drops below"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.background
                    .ignoresSafeArea()

                Form {
                    Section {
                        TextField("Card ID (e.g., sv1-25)", text: $cardId)
                            .autocapitalization(.none)

                        TextField("Card Name", text: $cardName)
                    } header: {
                        Text("Card")
                    }
                    .listRowBackground(Color.theme.surface)

                    Section {
                        Picker("Alert when", selection: $alertType) {
                            ForEach(AlertType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }

                        HStack {
                            Text("$")
                            TextField("Target Price", text: $targetPrice)
                                .keyboardType(.decimalPad)
                        }
                    } header: {
                        Text("Condition")
                    }
                    .listRowBackground(Color.theme.surface)

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.theme.negative)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createAlert()
                    }
                    .disabled(isCreating || cardId.isEmpty || cardName.isEmpty || targetPrice.isEmpty)
                }
            }
        }
    }

    private func createAlert() {
        guard let price = Double(targetPrice) else {
            errorMessage = "Invalid price"
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let request = CreateAlertRequest(
                    cardId: cardId,
                    cardName: cardName,
                    targetPrice: price,
                    alertType: alertType.rawValue
                )
                _ = try await APIService.shared.createAlert(request)
                await onCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

#Preview {
    NavigationStack {
        AlertsListView()
    }
}
