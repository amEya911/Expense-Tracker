import Foundation
import FirebaseCore
import FirebaseStorage

@Observable
final class StorageService: Sendable {
    var storage: Storage {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return Storage.storage()
    }

    private func avatarRef(for userId: String) -> StorageReference {
        storage.reference().child("users").child(userId).child("avatar.jpg")
    }

    /// Uploads the user avatar JPEG image data to Firebase Storage at users/{userId}/avatar.jpg
    /// Overwrites existing avatar so there is only 1 file per user in storage.
    func uploadProfileImage(userId: String, imageData: Data) async throws -> URL {
        guard !userId.isEmpty else {
            throw NSError(domain: "StorageService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"])
        }

        let ref = avatarRef(for: userId)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadUrl = try await ref.downloadURL()
        return downloadUrl
    }

    /// Deletes the avatar image from Firebase Storage if user switches back to a default preset avatar.
    func deleteProfileImage(userId: String) async throws {
        guard !userId.isEmpty else { return }
        let ref = avatarRef(for: userId)
        do {
            try await ref.delete()
        } catch let error as NSError {
            // Ignore error if the object does not exist in storage
            if error.domain == StorageErrorDomain && error.code == StorageErrorCode.objectNotFound.rawValue {
                return
            }
            throw error
        }
    }
}
