import SwiftUI

struct OnboardingView: View {
    let firestoreService: FirestoreService
    let userId: String
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var monthlyBudgetText = ""
    @State private var isSaving = false

    private let totalPages = 3

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                whyTrackPage.tag(1)
                budgetSetupPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Bottom controls
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.appAccent : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation { currentPage -= 1 }
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if currentPage < totalPages - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("Next")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(.appAccent)
                                .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            Task { await completeOnboarding() }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Get Started")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(.appAccent)
                            .clipShape(Capsule())
                        }
                        .disabled(isSaving)
                    }
                }

                // Skip button
                if currentPage < totalPages - 1 {
                    Button("Skip Setup") {
                        Task { await completeOnboarding() }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.appAccent)

            Text("Welcome to\nExpense Tracker")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("The simplest way to track your spending and stay on top of your finances.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    private var whyTrackPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 80))
                .foregroundStyle(.appAccent)

            Text("Know Where\nYour Money Goes")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "clock", text: "Add expenses in seconds")
                featureRow(icon: "chart.pie", text: "See spending by category")
                featureRow(icon: "target", text: "Set budgets and stay on track")
                featureRow(icon: "lightbulb", text: "Get personalized insights")
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    private var budgetSetupPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 80))
                .foregroundStyle(.appAccent)

            Text("Set Your\nMonthly Budget")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("How much do you want to spend each month? You can always change this later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack {
                Text("$")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                TextField("2,000", text: $monthlyBudgetText)
                    .font(.title2)
                    .keyboardType(.decimalPad)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 40)

            Text("Leave blank to skip — you can set a budget anytime from Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.appAccent)
                .frame(width: 32)
            Text(text)
                .font(.body)
        }
    }

    // MARK: - Actions

    private func completeOnboarding() async {
        isSaving = true
        do {
            // Save budget if provided
            if let budgetValue = Decimal(string: monthlyBudgetText), budgetValue > 0 {
                let budget = Budget(
                    userId: userId,
                    overallLimit: budgetValue
                )
                try await firestoreService.saveBudget(budget)
            }

            // Mark onboarding as complete
            var profile = try await firestoreService.getProfile(userId: userId)
                ?? UserProfile(userId: userId)
            profile.onboardingCompleted = true
            try await firestoreService.saveProfile(profile)

            onComplete()
        } catch {
            print("Onboarding save error: \(error.localizedDescription)")
            // Complete anyway — don't block the user
            onComplete()
        }
        isSaving = false
    }
}
