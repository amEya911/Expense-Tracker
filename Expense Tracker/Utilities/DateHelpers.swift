import Foundation

enum DateHelpers {
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let displayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    static func monthYearKey(for date: Date = Date()) -> String {
        monthYearFormatter.string(from: date)
    }

    static func displayMonth(for date: Date = Date()) -> String {
        displayMonthFormatter.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func startOfMonth(for date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func endOfMonth(for date: Date = Date()) -> Date {
        let calendar = Calendar.current
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            return date
        }
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
    }

    static func daysInMonth(for date: Date = Date()) -> Int {
        let calendar = Calendar.current
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    static func dayOfMonth(for date: Date = Date()) -> Int {
        Calendar.current.component(.day, from: date)
    }

    static func daysRemainingInMonth(for date: Date = Date()) -> Int {
        daysInMonth(for: date) - dayOfMonth(for: date)
    }

    static func previousMonth(from date: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date
    }

    static func transactionGroupLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let weekday = DateFormatter()
            weekday.dateFormat = "EEEE"
            return weekday.string(from: date)
        } else {
            return shortDate(date)
        }
    }

    static func isSameMonth(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, equalTo: date2, toGranularity: .month)
    }
}
