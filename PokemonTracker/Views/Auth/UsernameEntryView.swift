import SwiftUI

struct UsernameEntryView: View {
    @ObservedObject var authService = AuthService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var storedUsername = ""

    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private var isValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 20
            && trimmed.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            Color.pokemon.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "circle.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color.pokemon.primary)

                        HStack(spacing: 8) {
                            Text("Pokemon")
                                .foregroundColor(Color.pokemon.primary)
                            Text("Tracker")
                                .foregroundColor(Color.pokemon.gold)
                        }
                        .font(.largeTitle)
                        .fontWeight(.bold)

                        Text("Choose Your Trainer Name")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(Color.pokemon.textPrimary)
                    }

                    // Username field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.caption)
                            .foregroundColor(Color.pokemon.textSecondary)

                        TextField("", text: $username, prompt: Text("Enter a username").foregroundColor(Color.pokemon.textSecondary.opacity(0.5)))
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        Text("3-20 characters, letters, numbers, and underscores")
                            .font(.caption2)
                            .foregroundColor(Color.pokemon.textSecondary)
                    }
                    .padding(.horizontal, 24)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color.pokemon.negative)
                            .padding(.horizontal, 24)
                    }

                    // Submit button
                    Button(action: submit) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Start Collecting")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isValid ? Color.pokemon.primary : Color.pokemon.surface)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isValid || isSubmitting)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                try await authService.signInWithUsername(username)
                storedUsername = username
                hasCompletedOnboarding = true
            } catch {
                errorMessage = "Something went wrong. Try a different username."
                print("Username auth error: \(error)")
            }
            isSubmitting = false
        }
    }
}

#Preview {
    UsernameEntryView()
}
