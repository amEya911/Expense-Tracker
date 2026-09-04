import SwiftUI

struct BillSplitterSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onLogExpense: ((Decimal, String) -> Void)?

    @State private var billAmountText: String = ""
    @State private var tipPercentage: Double = 15.0
    @State private var numberOfPeople: Int = 2
    @State private var placeOrEvent: String = ""
    @State private var includeTax: Bool = false
    @State private var taxRate: Double = 13.0 // Ontario HST default
    @State private var copiedMessage: Bool = false

    private let tipOptions: [Double] = [0, 10, 15, 18, 20]

    private var billAmount: Double {
        Double(billAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var taxAmount: Double {
        includeTax ? billAmount * (taxRate / 100.0) : 0
    }

    private var subtotalWithTax: Double {
        billAmount + taxAmount
    }

    private var tipAmount: Double {
        subtotalWithTax * (tipPercentage / 100.0)
    }

    private var grandTotal: Double {
        subtotalWithTax + tipAmount
    }

    private var perPersonShare: Double {
        numberOfPeople > 0 ? grandTotal / Double(numberOfPeople) : grandTotal
    }

    private var eTransferMessage: String {
        let event = placeOrEvent.trimmingCharacters(in: .whitespaces).isEmpty ? "our bill" : placeOrEvent.trimmingCharacters(in: .whitespaces)
        return "Hey! Your share for \(event) is $\(String(format: "%.2f", perPersonShare)) (Total: $\(String(format: "%.2f", grandTotal)) split among \(numberOfPeople) people). Please e-Transfer when you get a chance!"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Hero Share Card
                    heroShareCard

                    // MARK: - Bill Input Section
                    billDetailsSection

                    // MARK: - Tip Selector Section
                    tipSelectorSection

                    // MARK: - Split Count Section
                    splitCountSection

                    // MARK: - e-Transfer Request Message Card
                    if grandTotal > 0 {
                        eTransferCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .navigationTitle("Split Bill & Tip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                if perPersonShare > 0, let onLogExpense {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Log My Share") {
                            let dec = Decimal(perPersonShare)
                            let desc = placeOrEvent.trimmingCharacters(in: .whitespaces).isEmpty ? "Group Split" : placeOrEvent
                            onLogExpense(dec, desc)
                            dismiss()
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appAccent)
                    }
                }
            }
        }
    }

    // MARK: - Hero Share Card

    private var heroShareCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("EACH PERSON PAYS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Text("$\(String(format: "%.2f", perPersonShare))")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Color.appAccent)
                    .contentTransition(.numericText())
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Bill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(String(format: "%.2f", grandTotal))")
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Tip (\(Int(tipPercentage))%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(String(format: "%.2f", tipAmount))")
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Split By")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(numberOfPeople) people")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Bill Details Section

    private var billDetailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BILL DETAILS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            HStack {
                Text("$")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $billAmountText)
                    .font(.title2.bold())
                    .keyboardType(.decimalPad)

                if !billAmountText.isEmpty {
                    Button {
                        billAmountText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(14)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            TextField("Place or Description (e.g. Chipotle, Costco)", text: $placeOrEvent)
                .padding(14)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Toggle(isOn: $includeTax) {
                HStack(spacing: 6) {
                    Text("Add HST/Tax (\(Int(taxRate))%)")
                        .font(.subheadline.weight(.medium))
                }
            }
            .tint(Color.appAccent)
            .padding(.top, 2)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Tip Selector Section

    private var tipSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TIP PERCENTAGE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Spacer()

                Text("\(Int(tipPercentage))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appAccent)
            }

            HStack(spacing: 8) {
                ForEach(tipOptions, id: \.self) { tip in
                    let isSelected = tipPercentage == tip
                    Button {
                        tipPercentage = tip
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                    } label: {
                        Text("\(Int(tip))%")
                            .font(.subheadline.weight(isSelected ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.appAccent : Color(.tertiarySystemBackground))
                            .foregroundStyle(isSelected ? .black : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Split Count Section

    private var splitCountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPLIT AMONG")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(Color.appAccent)
                    Text("\(numberOfPeople) \(numberOfPeople == 1 ? "person" : "people")")
                        .font(.headline)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        if numberOfPeople > 1 {
                            numberOfPeople -= 1
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(numberOfPeople > 1 ? Color.appAccent : .secondary.opacity(0.3))
                    }
                    .disabled(numberOfPeople <= 1)

                    Button {
                        if numberOfPeople < 30 {
                            numberOfPeople += 1
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(14)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - e-Transfer Message Card

    private var eTransferCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(Color.appAccent)
                Text("Interac e-Transfer Request")
                    .font(.headline)
                Spacer()
            }

            Text(eTransferMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = eTransferMessage
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    withAnimation {
                        copiedMessage = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedMessage = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copiedMessage ? "checkmark" : "doc.on.doc.fill")
                        Text(copiedMessage ? "Copied!" : "Copy Message")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                ShareLink(item: eTransferMessage) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.appAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
