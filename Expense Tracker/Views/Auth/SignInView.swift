import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Logo / Brand
                    VStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.appAccent)

                        Text("Expense Tracker")
                            .font(.largeTitle.bold())

                        Text("Track spending. Stay on budget.\nSimple finances for students.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer(minLength: 20)

                    // Sign in with Apple
                    VStack(spacing: 16) {
                        SignInWithAppleButton(.signIn) { request in
                            let hashedNonce = viewModel.prepareAppleSignIn()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = hashedNonce
                        } onCompletion: { result in
                            Task {
                                await viewModel.handleAppleSignIn(result: result)
                            }
                        }
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        dividerRow

                        // Email / Password form
                        VStack(spacing: 14) {
                            TextField("Email", text: $viewModel.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(14)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            SecureField("Password", text: $viewModel.password)
                                .textContentType(viewModel.isSignUp ? .newPassword : .password)
                                .padding(14)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            if viewModel.isSignUp {
                                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding(14)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.appWarning)
                                .multilineTextAlignment(.center)
                        }

                        // Primary action button
                        Button {
                            Task { await viewModel.signInWithEmail() }
                        } label: {
                            Group {
                                if viewModel.isProcessing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.appAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(viewModel.isProcessing)

                        // Toggle sign up / sign in
                        HStack(spacing: 4) {
                            Text(viewModel.isSignUp ? "Already have an account?" : "Don't have an account?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(viewModel.isSignUp ? "Sign In" : "Sign Up") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.isSignUp.toggle()
                                    viewModel.errorMessage = nil
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.appAccent)
                        }

                        if !viewModel.isSignUp {
                            Button("Forgot Password?") {
                                viewModel.resetEmail = viewModel.email
                                viewModel.showPasswordReset = true
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .alert("Reset Password", isPresented: $viewModel.showPasswordReset) {
                TextField("Email", text: $viewModel.resetEmail)
                Button("Send Reset Link") {
                    Task { await viewModel.sendPasswordReset() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(viewModel.resetSent
                     ? "Password reset email sent! Check your inbox."
                     : "Enter your email address to receive a password reset link.")
            }
        }
    }

    private var dividerRow: some View {
        HStack {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
        }
    }
}
