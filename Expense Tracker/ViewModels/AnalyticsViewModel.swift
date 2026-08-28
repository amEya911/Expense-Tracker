import Foundation
import SwiftUI
import Charts

@Observable
final class AnalyticsViewModel {
    var expenses: [Expense] = []
    var allTimeExpenses: [Expense] = []
    var categories: [ExpenseCategory] = []
    var budget: Budget?
    var prestoBalance: Decimal = .zero
    var prestoLoaded: Decimal = .zero
    var prestoUsed: Decimal = .zero
    var isLoading = true
    var selectedMonth = Date()

    let firestoreService: FirestoreService
    let userId: String

    init(firestoreService: FirestoreService, userId: String) {
        self.firestoreService = firestoreService
        self.userId = userId
    }

    var monthKey: String {
        DateHelpers.monthYearKey(for: selectedMonth)
    }

    var displayMonth: String {
        DateHelpers.displayMonth(for: selectedMonth)
    }

    var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Core Monthly Metrics (Excludes PRESTO transit card deductions)

    var totalSpent: Decimal {
        expenses
            .filter { !$0.isPrestoPayment }
            .reduce(.zero) { $0 + $1.decimalAmount }
    }

    var dailyAverage: Decimal {
        let calendar = Calendar.current
        let days: Int
        if isCurrentMonth {
            days = max(calendar.component(.day, from: Date()), 1)
        } else {
            days = max(DateHelpers.daysInMonth(for: selectedMonth), 1)
        }
        return totalSpent / Decimal(days)
    }

    var projectedMonthlyTotal: Decimal {
        let totalDays = DateHelpers.daysInMonth(for: selectedMonth)
        return dailyAverage * Decimal(totalDays)
    }

    // MARK: - Payment Method Models & Meta Helpers

    struct PaymentMethodSpending: Identifiable {
        let id: String
        let name: String
        let icon: String
        let color: Color
        let amount: Decimal
        let percentage: Double
        let count: Int
    }

    static func paymentMethodMeta(for method: String) -> (icon: String, color: Color) {
        let m = method.lowercased()
        if m.contains("presto") {
            return ("tram.fill", Color(hex: "00C48C"))
        } else if m.contains("forex") {
            return ("globe.americas.fill", Color.purple)
        } else if m.contains("credit") {
            return ("creditcard.fill", Color.indigo)
        } else if m.contains("debit") {
            return ("creditcard", Color.teal)
        } else if m.contains("cash") {
            return ("banknote.fill", Color.green)
        } else if m.contains("transfer") || m.contains("interac") {
            return ("arrow.left.arrow.right.circle.fill", Color.blue)
        } else {
            return ("dollarsign.circle.fill", Color.secondary)
        }
    }

    var paymentMethodBreakdown: [PaymentMethodSpending] {
        let total = expenses.reduce(Decimal.zero) { $0 + $1.decimalAmount }
        guard total > 0 else { return [] }

        var methodTotals: [String: Decimal] = [:]
        var methodCounts: [String: Int] = [:]

        for e in expenses {
            let method = (!e.paymentMethod.orEmpty.isEmpty) ? e.paymentMethod! : "Other"
            methodTotals[method, default: .zero] += e.decimalAmount
            methodCounts[method, default: 0] += 1
        }

        return methodTotals.map { (method, amt) in
            let meta = AnalyticsViewModel.paymentMethodMeta(for: method)
            let pct = NSDecimalNumber(decimal: (amt / total) * 100).doubleValue
            return PaymentMethodSpending(
                id: method,
                name: method,
                icon: meta.icon,
                color: meta.color,
                amount: amt,
                percentage: pct,
                count: methodCounts[method] ?? 0
            )
        }.sorted { $0.amount > $1.amount }
    }

    // MARK: - Category & Time Series Models

    struct CategorySpendingSlice: Identifiable {
        let id: String
        let name: String
        let icon: String
        let color: Color
        let amount: Decimal
        let percentage: Double
    }

    var categoryBreakdown: [CategorySpendingSlice] {
        let total = totalSpent
        guard total > 0 else { return [] }

        var spendMap: [String: Decimal] = [:]
        for e in expenses where !e.isPrestoPayment {
            spendMap[e.categoryId, default: .zero] += e.decimalAmount
        }

        let slices = categories.compactMap { cat -> CategorySpendingSlice? in
            guard let catId = cat.id, let amt = spendMap[catId], amt > 0 else { return nil }
            let pct = NSDecimalNumber(decimal: (amt / total) * 100).doubleValue
            return CategorySpendingSlice(
                id: catId,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                amount: amt,
                percentage: pct
            )
        }.sorted { $0.amount > $1.amount }

        return slices
    }

    struct DailySpendPoint: Identifiable {
        let id = UUID()
        let day: Int
        let date: Date
        let amount: Double
    }

    var dailySpendingPoints: [DailySpendPoint] {
        let calendar = Calendar.current
        let totalDays = isCurrentMonth ? calendar.component(.day, from: Date()) : DateHelpers.daysInMonth(for: selectedMonth)
        
        var dayTotals: [Int: Decimal] = [:]
        for day in 1...max(totalDays, 1) {
            dayTotals[day] = .zero
        }

        for e in expenses where !e.isPrestoPayment {
            let day = calendar.component(.day, from: e.date)
            dayTotals[day, default: .zero] += e.decimalAmount
        }

        return dayTotals.keys.sorted().map { day in
            var components = calendar.dateComponents([.year, .month], from: selectedMonth)
            components.day = day
            let date = calendar.date(from: components) ?? selectedMonth
            return DailySpendPoint(
                day: day,
                date: date,
                amount: NSDecimalNumber(decimal: dayTotals[day] ?? .zero).doubleValue
            )
        }
    }

    struct DayOfWeekStat: Identifiable {
        let id: Int
        let dayName: String
        let total: Decimal
        let average: Decimal
    }

    var dayOfWeekStats: [DayOfWeekStat] {
        let calendar = Calendar.current
        let daySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var totals: [Int: Decimal] = [:]
        var counts: [Int: Int] = [:]

        for i in 1...7 {
            totals[i] = .zero
            counts[i] = 0
        }

        for e in expenses where !e.isPrestoPayment {
            let weekday = calendar.component(.weekday, from: e.date)
            totals[weekday, default: .zero] += e.decimalAmount
            counts[weekday, default: 0] += 1
        }

        return (1...7).map { weekday in
            let total = totals[weekday] ?? .zero
            let count = max(counts[weekday] ?? 1, 1)
            return DayOfWeekStat(
                id: weekday,
                dayName: daySymbols[weekday - 1],
                total: total,
                average: total / Decimal(count)
            )
        }
    }

    // MARK: - Smart Student Insights

    var topSpendingDayOfWeek: String? {
        dayOfWeekStats.max(by: { $0.total < $1.total })?.dayName
    }

    var largestExpense: Expense? {
        expenses.filter { !$0.isPrestoPayment }.max(by: { $0.decimalAmount < $1.decimalAmount })
    }

    var coffeeSpent: Decimal {
        expenses.filter { e in
            let catName = categories.first(where: { $0.id == e.categoryId })?.name.lowercased() ?? ""
            return catName.contains("coffee") || e.merchant.lowercased().contains("tim") || e.merchant.lowercased().contains("starbucks")
        }.reduce(.zero) { $0 + $1.decimalAmount }
    }

    var prestoTransitRidesCount: Int {
        expenses.filter { $0.isPrestoPayment }.count
    }

    var prestoTransitSpent: Decimal {
        expenses.filter { $0.isPrestoPayment }.reduce(.zero) { $0 + $1.decimalAmount }
    }

    var groceriesSpent: Decimal {
        expenses.filter { e in
            let catName = categories.first(where: { $0.id == e.categoryId })?.name.lowercased() ?? ""
            return catName.contains("grocer")
        }.reduce(.zero) { $0 + $1.decimalAmount }
    }

    // MARK: - All-Time Metrics & Breakdowns

    var allTimeTotalSpent: Decimal {
        allTimeExpenses
            .filter { !$0.isPrestoPayment }
            .reduce(.zero) { $0 + $1.decimalAmount }
    }

    var allTimeTransactionCount: Int {
        allTimeExpenses.count
    }

    var allTimeAverageTransaction: Decimal {
        let nonPrestoCount = allTimeExpenses.filter { !$0.isPrestoPayment }.count
        guard nonPrestoCount > 0 else { return .zero }
        return allTimeTotalSpent / Decimal(nonPrestoCount)
    }

    var allTimePaymentBreakdown: [PaymentMethodSpending] {
        let total = allTimeExpenses.reduce(Decimal.zero) { $0 + $1.decimalAmount }
        guard total > 0 else { return [] }

        var methodTotals: [String: Decimal] = [:]
        var methodCounts: [String: Int] = [:]

        for e in allTimeExpenses {
            let method = (!e.paymentMethod.orEmpty.isEmpty) ? e.paymentMethod! : "Other"
            methodTotals[method, default: .zero] += e.decimalAmount
            methodCounts[method, default: 0] += 1
        }

        return methodTotals.map { (method, amt) in
            let meta = AnalyticsViewModel.paymentMethodMeta(for: method)
            let pct = NSDecimalNumber(decimal: (amt / total) * 100).doubleValue
            return PaymentMethodSpending(
                id: method,
                name: method,
                icon: meta.icon,
                color: meta.color,
                amount: amt,
                percentage: pct,
                count: methodCounts[method] ?? 0
            )
        }.sorted { $0.amount > $1.amount }
    }

    var allTimeCategoryBreakdown: [CategorySpendingSlice] {
        let total = allTimeTotalSpent
        guard total > 0 else { return [] }

        var spendMap: [String: Decimal] = [:]
        for e in allTimeExpenses where !e.isPrestoPayment {
            spendMap[e.categoryId, default: .zero] += e.decimalAmount
        }

        return categories.compactMap { cat -> CategorySpendingSlice? in
            guard let catId = cat.id, let amt = spendMap[catId], amt > 0 else { return nil }
            let pct = NSDecimalNumber(decimal: (amt / total) * 100).doubleValue
            return CategorySpendingSlice(
                id: catId,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                amount: amt,
                percentage: pct
            )
        }.sorted { $0.amount > $1.amount }
    }

    struct MonthlyHistoryPoint: Identifiable {
        let id: String
        let monthLabel: String
        let amount: Double
    }

    var allTimeMonthlyTrends: [MonthlyHistoryPoint] {
        var monthTotals: [String: (date: Date, total: Decimal)] = [:]

        for e in allTimeExpenses where !e.isPrestoPayment {
            let key = DateHelpers.monthYearKey(for: e.date)
            let existing = monthTotals[key]?.total ?? .zero
            monthTotals[key] = (date: e.date, total: existing + e.decimalAmount)
        }

        let sortedKeys = monthTotals.keys.sorted()
        return sortedKeys.map { key in
            let entry = monthTotals[key]!
            let label = DateHelpers.displayMonth(for: entry.date)
            return MonthlyHistoryPoint(
                id: key,
                monthLabel: label,
                amount: NSDecimalNumber(decimal: entry.total).doubleValue
            )
        }
    }

    var allTimeTopMerchant: (name: String, amount: Decimal)? {
        var map: [String: Decimal] = [:]
        for e in allTimeExpenses where !e.merchant.isEmpty && !e.isPrestoPayment {
            map[e.merchant, default: .zero] += e.decimalAmount
        }
        guard let top = map.max(by: { $0.value < $1.value }) else { return nil }
        return (name: top.key, amount: top.value)
    }

    var allTimeTopCategory: (name: String, amount: Decimal)? {
        guard let top = allTimeCategoryBreakdown.first else { return nil }
        return (name: top.name, amount: top.amount)
    }

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        do {
            let startDate = DateHelpers.startOfMonth(for: selectedMonth)
            let endDate = DateHelpers.endOfMonth(for: selectedMonth)

            async let expResult = firestoreService.getExpenses(userId: userId, startDate: startDate, endDate: endDate)
            async let allExpResult = firestoreService.getExpenses(userId: userId)
            async let catResult = firestoreService.getCategories(userId: userId)
            async let budgetResult = firestoreService.getBudget(userId: userId, monthYear: monthKey)
            async let prestoResult = firestoreService.getPrestoMetrics(userId: userId)

            let (loadedExp, loadedAllExp, loadedCats, loadedBudget, prestoMetrics) = try await (
                expResult, allExpResult, catResult, budgetResult, prestoResult
            )
            expenses = loadedExp
            allTimeExpenses = loadedAllExp
            categories = loadedCats
            budget = loadedBudget
            prestoBalance = prestoMetrics.balance
            prestoLoaded = prestoMetrics.totalLoaded
            prestoUsed = prestoMetrics.totalUsed
        } catch {
            print("[AnalyticsViewModel] Load error: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func goToPreviousMonth() {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = prev
            Task { await loadData() }
        }
    }

    func goToNextMonth() {
        guard !isCurrentMonth else { return }
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = next
            Task { await loadData() }
        }
    }
}

// MARK: - Helper Extension

private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
