import Foundation
import FirebaseAuth
import AuthenticationServices

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isSignUp = false
    var errorMessage: String?
    var isProcessing = false
    var showPasswordReset = false
    var resetEmail = ""
    var resetSent = false

    // Sign in with Apple state
    var currentNonce: String?

    private let authService: AuthService
    private let firestoreService: FirestoreService

    init(authService: AuthService, firestoreService: FirestoreService) {
        self.authService = authService
        self.firestoreService = firestoreService
    }

    var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && password.count >= 6 && password == confirmPassword
        }
        return !email.isEmpty && !password.isEmpty
    }

    func signInWithEmail() async {
        guard isFormValid else {
            errorMessage = isSignUp ? "Please fill all fields. Password must be at least 6 characters and match." : "Please enter your email and password."
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
                // Create profile for new user
                if let user = authService.currentUser {
                    await createProfileIfNeeded(user: user)
                }
            } else {
                try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    // MARK: - Sign in with Apple

    func prepareAppleSignIn() -> String {
        let nonce = authService.randomNonceString()
        currentNonce = nonce
        return authService.sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isProcessing = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let nonce = currentNonce else {
                errorMessage = "Invalid sign-in state. Please try again."
                isProcessing = false
                return
            }
            do {
                try await authService.signInWithApple(authorization: authorization, nonce: nonce)
                if let user = authService.currentUser {
                    await createProfileIfNeeded(user: user)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            // User cancelled - don't show error
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }

        isProcessing = false
    }

    func sendPasswordReset() async {
        guard !resetEmail.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        isProcessing = true
        do {
            try await authService.sendPasswordReset(email: resetEmail)
            resetSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    // MARK: - Profile Creation

    private func createProfileIfNeeded(user: FirebaseAuth.User) async {
        do {
            let existingProfile = try await firestoreService.getProfile(userId: user.uid)
            if existingProfile == nil {
                let profile = UserProfile(
                    userId: user.uid,
                    displayName: user.displayName ?? "",
                    email: user.email ?? ""
                )
                try await firestoreService.saveProfile(profile)
                try await firestoreService.seedDefaultCategories(userId: user.uid)
            }
        } catch {
            // Profile creation failed but user is authenticated — handle gracefully
            print("Failed to create profile: \(error.localizedDescription)")
        }
    }
}
