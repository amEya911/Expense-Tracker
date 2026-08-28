import Foundation
import FirebaseAuth
import SwiftUI

@Observable
final class SettingsViewModel {
    var profile: UserProfile?
    var isLoading = true
    var isSaving = false
    var isDeleting = false
    var errorMessage: String?
    var showDeleteConfirmation = false
    var showSignOutConfirmation = false

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let storageService: StorageService

    init(
        authService: AuthService,
        firestoreService: FirestoreService,
        storageService: StorageService = StorageService()
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.storageService = storageService
    }

    var userId: String {
        authService.currentUser?.uid ?? ""
    }

    var displayName: String {
        if let name = profile?.displayName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        if let authName = authService.currentUser?.displayName, !authName.trimmingCharacters(in: .whitespaces).isEmpty {
            return authName
        }
        let em = email
        if em.contains("@") {
            let parts = em.split(separator: "@")
            if let first = parts.first, !first.isEmpty {
                return String(first).capitalized
            }
        }
        return "Student"
    }

    var email: String {
        if let mail = profile?.email, !mail.trimmingCharacters(in: .whitespaces).isEmpty {
            return mail
        }
        if let authMail = authService.currentUser?.email, !authMail.trimmingCharacters(in: .whitespaces).isEmpty {
            return authMail
        }
        return "student@utoronto.ca"
    }

    var avatarIcon: String {
        profile?.avatarIcon ?? "person.crop.circle.fill"
    }

    var avatarColorHex: String {
        profile?.avatarColorHex ?? "00C48C"
    }

    var avatarUrl: String? {
        profile?.avatarUrl
    }

    var avatarColor: Color {
        Color(hex: avatarColorHex)
    }

    func loadProfile() async {
        guard let uid = authService.currentUser?.uid else { return }
        isLoading = true
        do {
            var loaded = try await firestoreService.getProfile(userId: uid)
            if loaded == nil {
                // Initialize default profile
                let fallback = UserProfile(
                    userId: uid,
                    displayName: authService.currentUser?.displayName ?? "",
                    email: authService.currentUser?.email ?? "",
                    avatarIcon: "person.crop.circle.fill",
                    avatarColorHex: "00C48C"
                )
                try? await firestoreService.saveProfile(fallback)
                loaded = fallback
            } else if loaded?.email.isEmpty == true, let authEmail = authService.currentUser?.email {
                loaded?.email = authEmail
                try? await firestoreService.saveProfile(loaded!)
            }
            profile = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Updates the user profile.
    /// If newImageData is provided, it is uploaded to Firebase Storage (overwriting previous avatar).
    /// If shouldRemoveCustomPhoto is true, the file in Firebase Storage is deleted to save space.
    func updateProfile(
        displayName: String,
        avatarIcon: String,
        avatarColorHex: String,
        newImageData: Data?,
        shouldRemoveCustomPhoto: Bool
    ) async -> Bool {
        guard let uid = authService.currentUser?.uid else { return false }
        isSaving = true
        errorMessage = nil

        var updated = profile ?? UserProfile(userId: uid)
        updated.displayName = displayName.trimmingCharacters(in: .whitespaces)
        updated.avatarIcon = avatarIcon
        updated.avatarColorHex = avatarColorHex

        do {
            if let imageData = newImageData {
                // 1. Upload compressed image to Firebase Storage: users/{userId}/avatar.jpg
                let downloadUrl = try await storageService.uploadProfileImage(userId: uid, imageData: imageData)
                updated.avatarUrl = downloadUrl.absoluteString
            } else if shouldRemoveCustomPhoto {
                // 2. User reverted to preset avatar: delete image from Firebase Storage to save space
                try? await storageService.deleteProfileImage(userId: uid)
                updated.avatarUrl = nil
            }

            // 3. Save profile metadata with the single PFP URL to Firestore
            try await firestoreService.saveProfile(updated)
            profile = updated
            isSaving = false
            return true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }

    func deleteAccount() async {
        guard let uid = authService.currentUser?.uid else { return }
        isDeleting = true
        errorMessage = nil

        do {
            // Delete avatar from Firebase Storage if exists
            try? await storageService.deleteProfileImage(userId: uid)
            // Delete all Firestore data
            try await firestoreService.deleteAllUserData(userId: uid)
            // Delete the Firebase Auth account
            try await authService.deleteAccount()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }

        isDeleting = false
    }
}
