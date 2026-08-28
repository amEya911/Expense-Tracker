import Foundation
import SwiftUI
import Charts

@Observable
final class AnalyticsViewModel {
    var expenses: [Expense] = []
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

    // MARK: - Core Metrics (Excluding PRESTO card deductions to prevent double counting)

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

    // MARK: - Chart Data Models

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

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        do {
            let startDate = DateHelpers.startOfMonth(for: selectedMonth)
            let endDate = DateHelpers.endOfMonth(for: selectedMonth)

            async let expResult = firestoreService.getExpenses(userId: userId, startDate: startDate, endDate: endDate)
            async let catResult = firestoreService.getCategories(userId: userId)
            async let budgetResult = firestoreService.getBudget(userId: userId, monthYear: monthKey)
            async let prestoResult = firestoreService.getPrestoMetrics(userId: userId)

            let (loadedExp, loadedCats, loadedBudget, prestoMetrics) = try await (
                expResult, catResult, budgetResult, prestoResult
            )
            expenses = loadedExp
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
