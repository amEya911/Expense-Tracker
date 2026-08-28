import Foundation
import UIKit

@Observable
final class ExpenseViewModel {
    // Input fields (Compulsory: amount, category, merchant, date, paymentMethod)
    var amountText = ""
    var selectedCategoryId: String?
    var merchant = ""
    var date = Date()
    var notes = ""
    var paymentMethod: String?

    // State
    var categories: [ExpenseCategory] = []
    var recentMerchants: [String] = []
    var prestoBalance: Decimal = .zero
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    // Edit mode
    var editingExpense: Expense?
    var isEditing: Bool { editingExpense != nil }

    let firestoreService: FirestoreService
    let userId: String

    init(firestoreService: FirestoreService, userId: String) {
        self.firestoreService = firestoreService
        self.userId = userId
    }

    var displayAmount: String {
        if amountText.isEmpty { return "$0.00" }
        if let dec = Decimal(string: amountText) {
            return CurrencyFormatter.format(dec)
        }
        return "$0.00"
    }

    var amount: Decimal {
        Decimal(string: amountText) ?? .zero
    }

    var isPrestoSelected: Bool {
        paymentMethod?.trimmingCharacters(in: .whitespaces).uppercased() == "PRESTO"
    }

    var hasInsufficientPrestoBalance: Bool {
        isPrestoSelected && amount > prestoBalance
    }

    var validationError: String? {
        if amount <= 0 {
            return "Enter an amount greater than $0"
        }
        if selectedCategoryId == nil && categories.isEmpty {
            return "Select a category"
        }
        if merchant.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Enter a merchant or transit mode"
        }
        if paymentMethod == nil || paymentMethod!.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Select a payment method"
        }
        if hasInsufficientPrestoBalance {
            return "Insufficient PRESTO balance (\(CurrencyFormatter.format(prestoBalance)) available)"
        }
        return nil
    }

    var canSave: Bool {
        validationError == nil
    }

    var selectedCategory: ExpenseCategory? {
        if let id = selectedCategoryId {
            return categories.first { $0.id == id }
        }
        return categories.first
    }

    func loadData() async {
        do {
            async let cats = firestoreService.getCategories(userId: userId)
            async let merchants = firestoreService.getRecentMerchants(userId: userId)
            async let prestoMetrics = firestoreService.getPrestoMetrics(userId: userId)

            let (loadedCats, loadedMerchants, metrics) = try await (cats, merchants, prestoMetrics)

            categories = loadedCats.filter { !$0.isArchived }
            recentMerchants = loadedMerchants
            prestoBalance = metrics.balance

            // Auto-select first category if none selected
            if selectedCategoryId == nil || !categories.contains(where: { $0.id == selectedCategoryId }) {
                selectedCategoryId = categories.first?.id
            }
        } catch {
            print("Failed to load expense data: \(error.localizedDescription)")
            if categories.isEmpty {
                categories = DefaultCategory.all.enumerated().map { index, cat in
                    ExpenseCategory(
                        id: "default_\(index)",
                        userId: userId,
                        name: cat.name,
                        icon: cat.icon,
                        colorHex: cat.color,
                        sortOrder: cat.sortOrder,
                        isDefault: true
                    )
                }
                selectedCategoryId = categories.first?.id
            }
        }
    }

    func loadForEditing(_ expense: Expense) {
        editingExpense = expense
        let val = NSDecimalNumber(decimal: expense.decimalAmount).doubleValue
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            amountText = String(format: "%.0f", val)
        } else {
            amountText = String(format: "%.2f", val)
        }
        selectedCategoryId = expense.categoryId
        merchant = expense.merchant
        date = expense.date
        notes = expense.notes
        paymentMethod = expense.paymentMethod
    }

    func save() async {
        guard canSave else {
            errorMessage = validationError ?? "Please fill in all required fields."
            return
        }

        let catId = selectedCategoryId ?? categories.first?.id ?? ""
        isSaving = true
        errorMessage = nil

        do {
            if var existing = editingExpense {
                existing.decimalAmount = amount
                existing.categoryId = catId
                existing.merchant = merchant.trimmingCharacters(in: .whitespaces)
                existing.date = date
                existing.notes = notes.trimmingCharacters(in: .whitespaces)
                existing.paymentMethod = paymentMethod
                existing.updatedAt = Date()
                try await firestoreService.updateExpense(existing)
            } else {
                let expense = Expense(
                    userId: userId,
                    amount: amount,
                    categoryId: catId,
                    merchant: merchant.trimmingCharacters(in: .whitespaces),
                    date: date,
                    notes: notes.trimmingCharacters(in: .whitespaces),
                    paymentMethod: paymentMethod
                )
                _ = try await firestoreService.addExpense(expense)
            }

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            didSave = true
        } catch {
            print("[ExpenseViewModel] Save error: \(error.localizedDescription)")
            errorMessage = "Failed to save expense: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }

        isSaving = false
    }

    func reset() {
        amountText = ""
        selectedCategoryId = categories.first?.id
        merchant = ""
        date = Date()
        notes = ""
        paymentMethod = nil
        editingExpense = nil
        didSave = false
        errorMessage = nil
    }
}
