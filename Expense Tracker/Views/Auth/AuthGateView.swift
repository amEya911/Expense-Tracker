import SwiftUI
import FirebaseAuth

struct AuthGateView: View {
    let authService: AuthService
    let firestoreService: FirestoreService

    @State private var hasCompletedOnboarding = false
    @State private var isCheckingOnboarding = true

    var body: some View {
        Group {
            if authService.isLoading {
                loadingView
            } else if !authService.isAuthenticated {
                SignInView(viewModel: AuthViewModel(authService: authService, firestoreService: firestoreService))
            } else if isCheckingOnboarding {
                loadingView
                    .task { await checkOnboarding() }
            } else if !hasCompletedOnboarding {
                OnboardingView(
                    firestoreService: firestoreService,
                    userId: authService.currentUser?.uid ?? "",
                    onComplete: {
                        hasCompletedOnboarding = true
                    }
                )
            } else {
                MainTabView(
                    authService: authService,
                    firestoreService: firestoreService,
                    userId: authService.currentUser?.uid ?? ""
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }

    private var loadingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.2)
        }
    }

    private func checkOnboarding() async {
        guard let userId = authService.currentUser?.uid else {
            isCheckingOnboarding = false
            return
        }
        do {
            let profile = try await firestoreService.getProfile(userId: userId)
            hasCompletedOnboarding = profile?.onboardingCompleted ?? false
        } catch {
            hasCompletedOnboarding = false
        }
        isCheckingOnboarding = false
    }
}
