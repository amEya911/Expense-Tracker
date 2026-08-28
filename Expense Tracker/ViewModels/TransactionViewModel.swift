import Foundation
import UIKit

@Observable
final class TransactionViewModel {
    var expenses: [Expense] = []
    var categories: [ExpenseCategory] = []
    var isLoading = true
    var searchText = ""
    var errorMessage: String?

    private let firestoreService: FirestoreService
    private let userId: String

    init(firestoreService: FirestoreService, userId: String) {
        self.firestoreService = firestoreService
        self.userId = userId
    }

    var filteredExpenses: [Expense] {
        guard !searchText.isEmpty else { return expenses }
        let query = searchText.lowercased()
        return expenses.filter { expense in
            expense.merchant.lowercased().contains(query) ||
            expense.notes.lowercased().contains(query) ||
            categoryName(for: expense.categoryId).lowercased().contains(query)
        }
    }

    /// Groups expenses by display date label (Today, Yesterday, weekday, or date)
    var groupedExpenses: [(label: String, expenses: [Expense])] {
        let sorted = filteredExpenses.sorted { $0.date > $1.date }
        var groups: [(label: String, expenses: [Expense])] = []
        var currentLabel = ""
        var currentGroup: [Expense] = []

        for expense in sorted {
            let label = DateHelpers.transactionGroupLabel(for: expense.date)
            if label != currentLabel {
                if !currentGroup.isEmpty {
                    groups.append((label: currentLabel, expenses: currentGroup))
                }
                currentLabel = label
                currentGroup = [expense]
            } else {
                currentGroup.append(expense)
            }
        }
        if !currentGroup.isEmpty {
            groups.append((label: currentLabel, expenses: currentGroup))
        }

        return groups
    }

    func categoryName(for categoryId: String) -> String {
        categories.first { $0.id == categoryId }?.name ?? "Other"
    }

    func category(for categoryId: String) -> ExpenseCategory? {
        categories.first { $0.id == categoryId }
    }

    func loadData() async {
        isLoading = true
        do {
            async let expensesResult = firestoreService.getExpenses(userId: userId)
            async let categoriesResult = firestoreService.getCategories(userId: userId)
            let (loadedExpenses, loadedCategories) = try await (expensesResult, categoriesResult)
            expenses = loadedExpenses
            categories = loadedCategories
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else {
            print("[TransactionViewModel] Delete failed: expense.id is nil!")
            return
        }
        do {
            try await firestoreService.deleteExpense(userId: userId, expenseId: id)
            expenses.removeAll { $0.id == id }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("[TransactionViewModel] Delete error: \(error.localizedDescription)")
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
}
