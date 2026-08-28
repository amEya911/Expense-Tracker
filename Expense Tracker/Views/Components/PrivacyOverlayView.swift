import SwiftUI

struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Expense Tracker")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
