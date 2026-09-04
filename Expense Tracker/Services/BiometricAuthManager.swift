import Foundation
import LocalAuthentication
import SwiftUI

@Observable
final class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    var isUnlocked: Bool = false
    var isAuthenticating: Bool = false
    var authenticationError: String?

    var biometryType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType
        }
        return .none
    }

    var biometryName: String {
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Passcode"
        }
    }

    var biometryIcon: String {
        switch biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }

    func authenticate(reason: String = "Unlock your Expense Tracker") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        // Allow biometrics with fallback to device passcode
        let policy: LAPolicy = .deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: &error) else {
            // If device has no passcode/biometrics, allow access
            await MainActor.run {
                self.isUnlocked = true
                self.authenticationError = nil
            }
            return true
        }

        await MainActor.run {
            self.isAuthenticating = true
            self.authenticationError = nil
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            await MainActor.run {
                self.isUnlocked = success
                self.isAuthenticating = false
                if success {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                }
            }
            return success
        } catch {
            await MainActor.run {
                self.isUnlocked = false
                self.isAuthenticating = false
                self.authenticationError = error.localizedDescription
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.error)
            }
            return false
        }
    }

    func lock() {
        isUnlocked = false
    }

    func unlockDirectly() {
        isUnlocked = true
    }
}
