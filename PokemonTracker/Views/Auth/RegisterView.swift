import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }

    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "circle.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.theme.primary)

                        HStack(spacing: 8) {
                            Text("Pokemon")
                                .foregroundColor(.theme.primary)
                            Text("Tracker")
                                .foregroundColor(.theme.gold)
                        }
                        .font(.largeTitle)
                        .fontWeight(.bold)

                        Text("Join to track and sync your collection")
                            .font(.subheadline)
                            .foregroundColor(.theme.textSecondary)
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 16) {
                        // Username (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username (optional)")
                                .font(.caption)
                                .foregroundColor(.theme.textSecondary)

                            TextField("", text: $username)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }

                        // Email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.theme.textSecondary)

                            TextField("", text: $email)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.theme.textSecondary)

                            SecureField("", text: $password)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.newPassword)

                            if !password.isEmpty && password.count < 6 {
                                Text("Password must be at least 6 characters")
                                    .font(.caption2)
                                    .foregroundColor(.theme.negative)
                            }
                        }

                        // Confirm Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.caption)
                                .foregroundColor(.theme.textSecondary)

                            SecureField("", text: $confirmPassword)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.newPassword)

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Passwords do not match")
                                    .font(.caption2)
                                    .foregroundColor(.theme.negative)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.theme.negative)
                            .padding(.horizontal, 24)
                    }

                    // Sign Up button
                    Button(action: signUp) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.theme.primary : Color.theme.primary.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || authService.isLoading)
                    .padding(.horizontal, 24)

                    // Terms
                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption2)
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.theme.textPrimary)
                }
            }
        }
    }

    private func signUp() {
        errorMessage = nil
        Task {
            do {
                try await authService.signUp(
                    email: email,
                    password: password,
                    username: username.isEmpty ? nil : username
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
}
