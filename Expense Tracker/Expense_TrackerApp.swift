//
//  Expense_TrackerApp.swift
//  Expense Tracker
//
//  Created by Ameya Kulkarni on 27/08/26.
//

import SwiftUI
import UIKit
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyOverlay = false
    @AppStorage("appTheme") private var appTheme: String = "system"

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

                // Privacy overlay when app is in background
                if showPrivacyOverlay {
                    PrivacyOverlayView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(activeColorScheme)
            .animation(.easeInOut(duration: 0.15), value: showPrivacyOverlay)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    showPrivacyOverlay = false
                case .inactive, .background:
                    showPrivacyOverlay = true
                @unknown default:
                    break
                }
            }
        }
    }
}
