import Foundation

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = AppConstants.defaultCurrency
        f.locale = Locale(identifier: "en_CA")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    private static let compactFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = AppConstants.defaultCurrency
        f.locale = Locale(identifier: "en_CA")
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    static func format(_ amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    static func formatCompact(_ amount: Decimal) -> String {
        if amount >= 10000 {
            let thousands = amount / 1000
            return "$\(NSDecimalNumber(decimal: thousands).intValue)k"
        }
        return compactFormatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    static func formatInput(_ text: String) -> String {
        let digits = text.filter { $0.isNumber }
        guard let value = Int(digits) else { return "$0.00" }
        let decimal = Decimal(value) / 100
        return format(decimal)
    }

    static func decimalFromInput(_ text: String) -> Decimal {
        let digits = text.filter { $0.isNumber }
        guard let value = Int(digits) else { return 0 }
        return Decimal(value) / 100
    }
}
