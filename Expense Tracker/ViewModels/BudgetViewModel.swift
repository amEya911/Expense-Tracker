import Foundation

@Observable
final class BudgetViewModel {
    var budget: Budget?
    var categories: [ExpenseCategory] = []
    var categorySpending: [String: Decimal] = [:]
    var overallLimitText = ""
    var categoryLimitTexts: [String: String] = [:]
    var isLoading = true
    var isSaving = false
    var errorMessage: String?
    var currentMonth = Date()

    let firestoreService: FirestoreService
    let userId: String

    init(firestoreService: FirestoreService, userId: String) {
        self.firestoreService = firestoreService
        self.userId = userId
    }

    var monthKey: String {
        DateHelpers.monthYearKey(for: currentMonth)
    }

    var displayMonth: String {
        DateHelpers.displayMonth(for: currentMonth)
    }

    var overallLimit: Decimal? {
        budget?.decimalOverallLimit
    }

    var totalSpent: Decimal {
        categorySpending.values.reduce(.zero, +)
    }

    var overallRemaining: Decimal? {
        guard let limit = overallLimit else { return nil }
        return limit - totalSpent
    }

    var overallProgress: Double {
        guard let limit = overallLimit, limit > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: totalSpent / limit).doubleValue, 1.5)
    }

    struct CategoryBudgetInfo: Identifiable {
        let id: String
        let name: String
        let icon: String
        let colorHex: String
        let spent: Decimal
        let limit: Decimal?
        var progress: Double {
            guard let limit, limit > 0 else { return 0 }
            return min(NSDecimalNumber(decimal: spent / limit).doubleValue, 1.5)
        }
        var isOverBudget: Bool { progress > 1.0 }
    }

    var categoryBudgets: [CategoryBudgetInfo] {
        categories.filter { !$0.isArchived }.compactMap { cat in
            guard let catId = cat.id else { return nil }
            let spent = categorySpending[catId] ?? .zero
            let limit = budget?.decimalLimit(for: catId)
            // Only show categories that have spending or a budget
            guard spent > 0 || limit != nil else { return nil }
            return CategoryBudgetInfo(
                id: catId,
                name: cat.name,
                icon: cat.icon,
                colorHex: cat.colorHex,
                spent: spent,
                limit: limit
            )
        }.sorted { ($0.spent) > ($1.spent) }
    }

    func loadData() async {
        isLoading = true
        do {
            async let budgetResult = firestoreService.getBudget(userId: userId, monthYear: monthKey)
            async let categoriesResult = firestoreService.getCategories(userId: userId)
            async let spendingResult = firestoreService.getSpendingByCategory(userId: userId, monthYear: monthKey)

            let (loadedBudget, loadedCategories, loadedSpending) = try await (
                budgetResult, categoriesResult, spendingResult
            )

            budget = loadedBudget
            categories = loadedCategories
            categorySpending = loadedSpending

            // Populate text fields from existing budget
            if let limit = loadedBudget?.decimalOverallLimit {
                overallLimitText = NSDecimalNumber(decimal: limit).stringValue
            }
            if let catLimits = loadedBudget?.categoryLimits {
                for (catId, limit) in catLimits {
                    categoryLimitTexts[catId] = NSDecimalNumber(decimal: Decimal(limit)).stringValue
                }
            }
        } catch {
            errorMessage = "Failed to load budget: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func saveBudget() async {
        isSaving = true
        errorMessage = nil

        let overallDecimal: Decimal? = {
            guard !overallLimitText.isEmpty,
                  let value = Decimal(string: overallLimitText), value > 0 else { return nil }
            return value
        }()

        var catLimits: [String: Decimal] = [:]
        for (catId, text) in categoryLimitTexts {
            if let value = Decimal(string: text), value > 0 {
                catLimits[catId] = value
            }
        }

        do {
            var updatedBudget = budget ?? Budget(userId: userId, monthYear: monthKey)
            updatedBudget.decimalOverallLimit = overallDecimal
            updatedBudget.categoryLimits = catLimits.mapValues { NSDecimalNumber(decimal: $0).doubleValue }
            updatedBudget.updatedAt = Date()

            try await firestoreService.saveBudget(updatedBudget)
            budget = updatedBudget
        } catch {
            errorMessage = "Failed to save budget: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
