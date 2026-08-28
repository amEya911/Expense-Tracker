import Foundation
import FirebaseAuth

@Observable
final class SettingsViewModel {
    var profile: UserProfile?
    var isLoading = true
    var isDeleting = false
    var errorMessage: String?
    var showDeleteConfirmation = false
    var showSignOutConfirmation = false

    private let authService: AuthService
    private let firestoreService: FirestoreService

    init(authService: AuthService, firestoreService: FirestoreService) {
        self.authService = authService
        self.firestoreService = firestoreService
    }

    var displayName: String {
        profile?.displayName.isEmpty == false ? profile!.displayName :
            authService.currentUser?.displayName ?? "User"
    }

    var email: String {
        profile?.email ?? authService.currentUser?.email ?? ""
    }

    func loadProfile() async {
        guard let userId = authService.currentUser?.uid else { return }
        isLoading = true
        do {
            profile = try await firestoreService.getProfile(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }

    func deleteAccount() async {
        guard let userId = authService.currentUser?.uid else { return }
        isDeleting = true
        errorMessage = nil

        do {
            // Delete all Firestore data first
            try await firestoreService.deleteAllUserData(userId: userId)
            // Then delete the Firebase Auth account
            try await authService.deleteAccount()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }

        isDeleting = false
    }
}
