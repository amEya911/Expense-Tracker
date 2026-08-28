import Foundation

@Observable
final class DashboardViewModel {
    var totalSpent: Decimal = 0
    var budgetLimit: Decimal? = nil
    var categorySpending: [(categoryId: String, name: String, icon: String, colorHex: String, amount: Decimal)] = []
    var recentExpenses: [Expense] = []
    var prestoBalance: Decimal = 0
    var prestoLoaded: Decimal = 0
    var prestoSpent: Decimal = 0
    var isLoading = true
    var currentMonth = Date()

    let firestoreService: FirestoreService
    let userId: String

    init(firestoreService: FirestoreService, userId: String) {
        self.firestoreService = firestoreService
        self.userId = userId
    }

    var budgetRemaining: Decimal? {
        guard let limit = budgetLimit else { return nil }
        return limit - totalSpent
    }

    var budgetProgress: Double {
        guard let limit = budgetLimit, limit > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: totalSpent / limit).doubleValue, 1.5)
    }

    var isOverBudget: Bool {
        guard let remaining = budgetRemaining else { return false }
        return remaining < 0
    }

    var dailyAverage: Decimal {
        let day = DateHelpers.dayOfMonth(for: currentMonth)
        guard day > 0 else { return 0 }
        return totalSpent / Decimal(day)
    }

    var projectedMonthly: Decimal {
        let daysInMonth = DateHelpers.daysInMonth(for: currentMonth)
        guard daysInMonth > 0 else { return totalSpent }
        let day = DateHelpers.dayOfMonth(for: currentMonth)
        guard day > 0 else { return totalSpent }
        return (totalSpent / Decimal(day)) * Decimal(daysInMonth)
    }

    var displayMonth: String {
        DateHelpers.displayMonth(for: currentMonth)
    }

    var isCurrentMonth: Bool {
        DateHelpers.isSameMonth(currentMonth, Date())
    }

    /// Estimated standard TTC rides remaining at $3.30 per tap
    var estimatedTransitRides: Int {
        let fare: Decimal = 3.30
        guard prestoBalance >= fare else { return 0 }
        let balanceDouble = NSDecimalNumber(decimal: prestoBalance).doubleValue
        return Int(balanceDouble / 3.30)
    }

    func loadData() async {
        isLoading = true

        let monthKey = DateHelpers.monthYearKey(for: currentMonth)

        do {
            // Load spending (excluding PRESTO deductions), budget, PRESTO metrics, and recent transactions concurrently
            async let spendingResult = firestoreService.getMonthlySpending(userId: userId, monthYear: monthKey)
            async let budgetResult = firestoreService.getBudget(userId: userId, monthYear: monthKey)
            async let categoriesResult = firestoreService.getCategories(userId: userId)
            async let categorySpendingResult = firestoreService.getSpendingByCategory(userId: userId, monthYear: monthKey)
            async let recentResult = firestoreService.getExpenses(userId: userId, limit: AppConstants.maxRecentTransactions)
            async let prestoMetricsResult = firestoreService.getPrestoMetrics(userId: userId)

            let (spending, budget, categories, catSpending, recent, prestoMetrics) = try await (
                spendingResult, budgetResult, categoriesResult, categorySpendingResult, recentResult, prestoMetricsResult
            )

            totalSpent = spending
            budgetLimit = budget?.decimalOverallLimit
            recentExpenses = recent
            prestoBalance = prestoMetrics.balance
            prestoLoaded = prestoMetrics.totalLoaded
            prestoSpent = prestoMetrics.totalUsed

            // Build category spending with names and icons
            let categoryMap = Dictionary(uniqueKeysWithValues: categories.compactMap { cat in
                cat.id.map { ($0, cat) }
            })

            categorySpending = catSpending
                .sorted { $0.value > $1.value }
                .prefix(6)
                .compactMap { (catId, amount) in
                    guard let cat = categoryMap[catId] else { return nil }
                    return (categoryId: catId, name: cat.name, icon: cat.icon, colorHex: cat.colorHex, amount: amount)
                }

        } catch {
            print("Dashboard load error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func goToPreviousMonth() {
        currentMonth = DateHelpers.previousMonth(from: currentMonth)
        Task { await loadData() }
    }

    func goToNextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        Task { await loadData() }
    }
}
