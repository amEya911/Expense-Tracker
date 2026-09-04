//
//  Expense_TrackerApp.swift
//  Expense Tracker
//
//  Created by Ameya Kulkarni on 27/08/26.
//

import SwiftUI
import UIKit
import AppIntents
import FirebaseCore
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings

        return true
    }
}

@main
struct Expense_TrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var authService: AuthService
    @State private var firestoreService: FirestoreService
    @State private var biometricManager = BiometricAuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyOverlay = false
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("biometricsEnabled") private var biometricsEnabled: Bool = false

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            let settings = Firestore.firestore().settings
            settings.cacheSettings = PersistentCacheSettings()
            Firestore.firestore().settings = settings
        }

        _authService = State(initialValue: AuthService())
        _firestoreService = State(initialValue: FirestoreService())
    }

    private var activeColorScheme: ColorScheme? {
        switch appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AuthGateView(
                    authService: authService,
                    firestoreService: firestoreService
                )

                // Biometric lock protection
                if biometricsEnabled && !biometricManager.isUnlocked && authService.isAuthenticated {
                    BiometricLockView(biometricManager: biometricManager)
                        .transition(.opacity)
                        .zIndex(99)
                }

                // Privacy overlay when app is in background or app switcher
                if showPrivacyOverlay {
                    PrivacyOverlayView()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .preferredColorScheme(activeColorScheme)
            .animation(.easeInOut(duration: 0.2), value: showPrivacyOverlay)
            .animation(.easeInOut(duration: 0.2), value: biometricManager.isUnlocked)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    showPrivacyOverlay = false
                case .inactive:
                    showPrivacyOverlay = true
                case .background:
                    showPrivacyOverlay = true
                    if biometricsEnabled {
                        biometricManager.lock()
                    }
                @unknown default:
                    break
                }
            }
            .onAppear {
                ExpenseTrackerShortcuts.updateAppShortcutParameters()
                if !biometricsEnabled {
                    biometricManager.unlockDirectly()
                }
            }
        }
    }
}
