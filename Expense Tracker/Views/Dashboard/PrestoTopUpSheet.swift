import SwiftUI

struct PrestoTopUpSheet: View {
    let firestoreService: FirestoreService
    let userId: String
    let currentBalance: Decimal
    var onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = "25"
    @State private var paymentMethod: String = "Debit"
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private let presetAmounts: [Int] = [10, 20, 25, 50, 100]

    private var topUpAmount: Decimal {
        Decimal(string: amountText) ?? .zero
    }

    private var newBalance: Decimal {
        currentBalance + topUpAmount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // PRESTO Card Mini Preview
                    prestoCardPreview

                    // Amount Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SELECT TOP-UP AMOUNT")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        // Preset buttons
                        HStack(spacing: 8) {
                            ForEach(presetAmounts, id: \.self) { preset in
                                let isSelected = amountText == String(preset)
                                Button {
                                    amountText = String(preset)
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                } label: {
                                    Text("$\(preset)")
                                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? Color(hex: "00C48C") : Color(.secondarySystemBackground))
                                        .foregroundStyle(isSelected ? .black : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        // Custom amount input
                        HStack {
                            Text(AppConstants.currencySymbol)
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)

                            TextField("Custom amount", text: $amountText)
                                .font(.title3.bold().monospacedDigit())
                                .keyboardType(.decimalPad)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Payment Method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PAID WITH")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["Debit", "Credit", "E-Transfer", "Cash", "Forex Card"], id: \.self) { method in
                                    let isSelected = paymentMethod == method
                                    Button {
                                        paymentMethod = method
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                    } label: {
                                        Text(method)
                                            .font(.subheadline.weight(isSelected ? .bold : .medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? Color.primary.opacity(0.15) : Color(.secondarySystemBackground))
                                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.appWarning)
                    }

                    // Confirm Button
                    Button {
                        Task { await performTopUp() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "tram.circle.fill")
                                    .font(.headline)
                                Text("Top Up \(CurrencyFormatter.format(topUpAmount))")
                                    .font(.headline.bold())
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(topUpAmount > 0 ? Color(hex: "00C48C") : Color.secondary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(topUpAmount <= 0 || isSaving)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("PRESTO Top-Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var prestoCardPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tram.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color(hex: "00C48C"))
                    Text("PRESTO")
                        .font(.headline.weight(.black))
                        .tracking(1.5)
                }
                Spacer()
                Image(systemName: "wave.3.forward")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(currentBalance))
                        .font(.subheadline.bold().monospacedDigit())
                }

                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: "00C48C"))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEW BALANCE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: "00C48C"))
                    Text(CurrencyFormatter.format(newBalance))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(Color(hex: "00C48C"))
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: "11261F"), Color(hex: "0B1713")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: "00C48C").opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func performTopUp() async {
        guard topUpAmount > 0 else { return }
        isSaving = true
        errorMessage = nil

        do {
            // Find or seed PRESTO category ID
            let categories = try await firestoreService.getCategories(userId: userId)
            let prestoCatId = categories.first(where: { $0.name.lowercased().contains("presto") })?.id ?? "presto"

            let expense = Expense(
                userId: userId,
                amount: topUpAmount,
                categoryId: prestoCatId,
                merchant: "PRESTO Top-Up",
                date: Date(),
                notes: "Card Reload via \(paymentMethod)",
                paymentMethod: paymentMethod
            )

            _ = try await firestoreService.addExpense(expense)

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            onCompleted()
            dismiss()
        } catch {
            errorMessage = "Failed to top up: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }

        isSaving = false
    }
}
