import Foundation

struct SemesterBudget: Codable, Equatable, Sendable {
    var termName: String = "Fall 2026"
    var startDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1)) ?? Date()
    var endDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 20)) ?? Date()
    var totalBudget: Double = 4000.0
    var isEnabled: Bool = true

    var totalDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return max(1, (components.day ?? 110) + 1)
    }

    var daysElapsed: Int {
        let calendar = Calendar.current
        let today = Date()
        if today < startDate { return 0 }
        if today > endDate { return totalDays }
        let components = calendar.dateComponents([.day], from: startDate, to: today)
        return max(0, components.day ?? 0)
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let today = Date()
        if today > endDate { return 0 }
        let start = max(today, startDate)
        let components = calendar.dateComponents([.day], from: start, to: endDate)
        return max(1, (components.day ?? totalDays) + 1)
    }

    var initialDailyBudget: Double {
        totalDays > 0 ? totalBudget / Double(totalDays) : 0
    }

    func safeDailyBudget(spentSoFar: Double) -> Double {
        let remainingFunds = max(0, totalBudget - spentSoFar)
        return daysRemaining > 0 ? remainingFunds / Double(daysRemaining) : 0
    }

    func remainingFunds(spentSoFar: Double) -> Double {
        totalBudget - spentSoFar
    }

    func progressRatio(spentSoFar: Double) -> Double {
        totalBudget > 0 ? min(spentSoFar / totalBudget, 1.5) : 0
    }

    func timeProgressRatio() -> Double {
        totalDays > 0 ? min(Double(daysElapsed) / Double(totalDays), 1.0) : 0
    }
}
