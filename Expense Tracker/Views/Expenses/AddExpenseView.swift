import SwiftUI

struct AddExpenseView: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isMerchantFocused: Bool
    @FocusState private var isNotesFocused: Bool

    @State private var rawAmountString: String = ""
    @State private var showSuccessAnimation = false
    @State private var showVoiceInput = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Amount Card (Compulsory)
                    amountCard

                    // MARK: - Category Selection (Compulsory)
                    categorySection

                    // MARK: - Merchant / Transit Mode (Compulsory)
                    merchantSection

                    // MARK: - Date & Payment Method (Compulsory)
                    dateAndPaymentSection

                    // MARK: - Notes (Optional)
                    notesSection

                    // MARK: - Validation & Error Message
                    if let error = viewModel.errorMessage ?? viewModel.validationError {
                        Text(error)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(viewModel.errorMessage != nil || viewModel.hasInsufficientPrestoBalance ? .appWarning : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // MARK: - Save Button
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.isEditing ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 12) {
                        if !viewModel.isEditing {
                            Button {
                                showVoiceInput = true
                            } label: {
                                Image(systemName: "mic.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.appAccent)
                            }
                        }

                        Button(viewModel.isEditing ? "Update" : "Save") {
                            Task { await saveExpense() }
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.canSave ? Color.appAccent : Color.secondary.opacity(0.4))
                        .disabled(!viewModel.canSave || viewModel.isSaving)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isAmountFocused = false
                        isMerchantFocused = false
                        isNotesFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await viewModel.loadData()
                if !viewModel.amountText.isEmpty {
                    rawAmountString = viewModel.amountText
                } else {
                    isAmountFocused = true
                }
            }
            .overlay {
                if showSuccessAnimation {
                    successOverlay
                }
            }
            .onChange(of: viewModel.didSave) { _, didSave in
                if didSave {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showSuccessAnimation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showVoiceInput) {
                VoiceInputView(categories: viewModel.categories) { parsed in
                    applyVoiceResult(parsed)
                }
            }
        }
    }

    // MARK: - Amount Card

    private var amountCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("AMOUNT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text("*")
                    .font(.caption2.bold())
                    .foregroundStyle(.appWarning)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(AppConstants.currencySymbol)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $rawAmountString)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: true, vertical: false)
                    .onChange(of: rawAmountString) { _, newValue in
                        handleAmountTextChange(newValue)
                    }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture {
            isAmountFocused = true
        }
    }

    private func handleAmountTextChange(_ newValue: String) {
        // Filter valid numeric and decimal characters
        let filtered = newValue.filter { "0123456789.".contains($0) }
        
        // Ensure at most one decimal point
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            rawAmountString = components[0] + "." + components[1]
            return
        }
        
        // Limit to 2 decimal places
        if components.count == 2 && components[1].count > 2 {
            rawAmountString = components[0] + "." + String(components[1].prefix(2))
            return
        }

        if filtered != newValue {
            rawAmountString = filtered
        }

        viewModel.amountText = rawAmountString
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Text("CATEGORY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Text("*")
                        .font(.caption2.bold())
                        .foregroundStyle(.appWarning)
                }

                Spacer()

                if let selected = viewModel.selectedCategory {
                    Text(selected.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected.color)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(viewModel.categories) { category in
                        CategoryBubble(
                            category: category,
                            isSelected: viewModel.selectedCategoryId == category.id
                        ) {
                            viewModel.selectedCategoryId = category.id
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Merchant / Transit Section

    private var merchantSection: some View {
        let categoryName = viewModel.selectedCategory?.name ?? ""
        let isTransport = categoryName.lowercased().contains("transport") || categoryName.lowercased().contains("transit")

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text(isTransport ? "TRANSIT / MERCHANT" : "MERCHANT / PAYEE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text("*")
                    .font(.caption2.bold())
                    .foregroundStyle(.appWarning)
            }

            HStack {
                Image(systemName: isTransport ? "tram.fill" : "storefront.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                TextField(merchantPlaceholder(for: categoryName), text: $viewModel.merchant)
                    .focused($isMerchantFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)

                if !viewModel.merchant.isEmpty {
                    Button {
                        viewModel.merchant = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Contextual quick suggestions
            let quickSuggestions = contextualMerchants(for: categoryName)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickSuggestions, id: \.self) { item in
                        Button {
                            viewModel.merchant = item
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                        } label: {
                            Text(item)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.merchant == item ? Color.appAccent.opacity(0.2) : Color(.tertiarySystemBackground))
                                .foregroundStyle(viewModel.merchant == item ? Color.appAccent : Color.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func merchantPlaceholder(for categoryName: String) -> String {
        let name = categoryName.lowercased()
        if name.contains("transport") || name.contains("transit") {
            return "e.g., Subway, Bus, Streetcar, TTC, GO Train"
        } else if name.contains("presto") {
            return "e.g., PRESTO Top-Up, Station Vending"
        } else if name.contains("coffee") {
            return "e.g., Tim Hortons, Starbucks, Second Cup"
        } else if name.contains("grocer") {
            return "e.g., Metro, No Frills, Loblaws, T&T"
        } else if name.contains("dining") || name.contains("food") {
            return "e.g., McDonald's, Chipotle, Osmow's"
        } else if name.contains("textbook") || name.contains("school") {
            return "e.g., UofT Bookstore, Campus Store, Amazon"
        } else if name.contains("subscription") {
            return "e.g., Spotify, Netflix, YouTube, ChatGPT"
        } else if name.contains("shopping") {
            return "e.g., Amazon, Uniqlo, Winners, Dollarama"
        } else {
            return "e.g., Merchant or Payee name"
        }
    }

    private func contextualMerchants(for categoryName: String) -> [String] {
        let defaults = CategorySuggestions.defaultMerchants(for: categoryName)
        var result = defaults
        for m in viewModel.recentMerchants where !result.contains(m) {
            result.append(m)
        }
        return Array(result.prefix(8))
    }

    // MARK: - Date & Payment Method

    private var dateAndPaymentSection: some View {
        let categoryName = viewModel.selectedCategory?.name ?? ""
        let paymentOptions = CategorySuggestions.paymentMethods(for: categoryName)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("DATE & PAYMENT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text("*")
                    .font(.caption2.bold())
                    .foregroundStyle(.appWarning)
            }

            HStack(spacing: 8) {
                // Quick date pills
                datePill(title: "Today", isSelected: Calendar.current.isDateInToday(viewModel.date)) {
                    viewModel.date = Date()
                }

                datePill(title: "Yesterday", isSelected: Calendar.current.isDateInYesterday(viewModel.date)) {
                    viewModel.date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                }

                Spacer()

                DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.appAccent)
            }

            Divider().padding(.vertical, 2)

            // Dynamic Payment methods (PRESTO uses standard unselected styling)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(paymentOptions, id: \.self) { method in
                        let isSelected = viewModel.paymentMethod == method

                        Button {
                            if viewModel.paymentMethod == method {
                                viewModel.paymentMethod = nil
                            } else {
                                viewModel.paymentMethod = method
                            }
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                        } label: {
                            Text(method)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? Color.appAccent.opacity(0.2) : Color(.tertiarySystemBackground))
                                .foregroundStyle(isSelected ? Color.appAccent : Color.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            // Insufficient PRESTO balance warning
            if viewModel.hasInsufficientPrestoBalance {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.appWarning)
                    Text("Insufficient PRESTO balance (\(CurrencyFormatter.format(viewModel.prestoBalance)) available)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.appWarning)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func datePill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.appAccent : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES (OPTIONAL)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            TextField("Add a note...", text: $viewModel.notes)
                .focused($isNotesFocused)
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await saveExpense() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                    Text(viewModel.isEditing ? "Update Expense" : "Save Expense")
                        .font(.headline.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(viewModel.canSave ? Color.appAccent : Color.secondary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!viewModel.canSave || viewModel.isSaving)
        .padding(.top, 4)
    }

    private func saveExpense() async {
        isAmountFocused = false
        isMerchantFocused = false
        isNotesFocused = false
        await viewModel.save()
    }

    private func applyVoiceResult(_ parsed: ParsedExpense) {
        if let amount = parsed.amount {
            let val = NSDecimalNumber(decimal: amount).doubleValue
            if val.truncatingRemainder(dividingBy: 1) == 0 {
                rawAmountString = String(format: "%.0f", val)
            } else {
                rawAmountString = String(format: "%.2f", val)
            }
            viewModel.amountText = rawAmountString
        }

        if let categoryName = parsed.categoryName {
            // Match category name to available categories
            if let match = viewModel.categories.first(where: {
                $0.name.lowercased() == categoryName.lowercased()
            }) {
                viewModel.selectedCategoryId = match.id
            }
        }

        if let merchant = parsed.merchant {
            viewModel.merchant = merchant
        }

        if let date = parsed.date {
            viewModel.date = date
        }

        if let method = parsed.paymentMethod {
            viewModel.paymentMethod = method
        }

        // Give haptic feedback
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.appAccent)

                Text("Expense Saved!")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Category Bubble

struct CategoryBubble: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? category.color : category.color.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : category.color)
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white, lineWidth: 2)
                    }
                }

                Text(category.name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 68)
            }
        }
        .buttonStyle(.plain)
    }
}
