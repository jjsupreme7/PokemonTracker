import SwiftUI

struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Logo/Header
                        VStack(spacing: 16) {
                            Image(systemName: "circle.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.theme.primary)

                            HStack(spacing: 8) {
                                Text("Pokemon")
                                    .foregroundColor(.theme.primary)
                                Text("Tracker")
                                    .foregroundColor(.theme.gold)
                            }
                            .font(.largeTitle)
                            .fontWeight(.bold)

                            Text("Sign in to sync your collection")
                                .font(.subheadline)
                                .foregroundColor(.theme.textSecondary)
                        }
                        .padding(.top, 60)

                        // Form
                        VStack(spacing: 16) {
                            // Email field
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

                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.theme.textSecondary)

                                SecureField("", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.password)
                            }

                            // Forgot password
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    showForgotPassword = true
                                }
                                .font(.caption)
                                .foregroundColor(.theme.gold)
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

                        // Sign In button
                        Button(action: signIn) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.theme.primary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                        .padding(.horizontal, 24)

                        // Register link
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.theme.textSecondary)
                            Button("Sign Up") {
                                showRegister = true
                            }
                            .foregroundColor(.theme.primary)
                            .fontWeight(.semibold)
                        }
                        .font(.subheadline)

                        Spacer()
                    }
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
            .alert("Reset Password", isPresented: $showForgotPassword) {
                TextField("Email", text: $email)
                Button("Send Reset Link") {
                    Task {
                        try? await authService.resetPassword(email: email)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your email to receive a password reset link.")
            }
        }
    }

    private func signIn() {
        errorMessage = nil
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.theme.surface)
            .foregroundColor(.theme.textPrimary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.textSecondary.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    LoginView()
}
