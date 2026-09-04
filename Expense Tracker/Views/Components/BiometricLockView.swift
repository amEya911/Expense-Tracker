import SwiftUI

struct BiometricLockView: View {
    @Bindable var biometricManager: BiometricAuthManager

    var body: some View {
        ZStack {
            // Dark luxury glass background
            LinearGradient(
                colors: [
                    Color(hex: "081410"),
                    Color(hex: "0C1F18"),
                    Color(hex: "050B08")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated glowing security shield
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.12))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(Color.appAccent.opacity(0.06))
                        .frame(width: 180, height: 180)

                    Image(systemName: biometricManager.biometryIcon)
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(Color.appAccent)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 16)
                }

                VStack(spacing: 8) {
                    Text("Expense Tracker")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Unlock with \(biometricManager.biometryName) to access your financial records")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let error = biometricManager.authenticationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.appWarning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    Task {
                        _ = await biometricManager.authenticate()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: biometricManager.biometryIcon)
                            .font(.headline)
                        Text("Unlock with \(biometricManager.biometryName)")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 10, y: 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            Task {
                _ = await biometricManager.authenticate()
            }
        }
    }
}
