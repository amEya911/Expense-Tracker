import Foundation

enum CSVExportService {

    /// Generates RFC-compliant CSV formatted text from an array of expenses.
    static func generateCSV(expenses: [Expense], categories: [ExpenseCategory]) -> String {
        var csv = "Date,Merchant,Category,Amount,Payment Method,Notes\n"

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let sorted = expenses.sorted { $0.date > $1.date }

        for expense in sorted {
            let dateStr = escapeCSV(dateFormatter.string(from: expense.date))
            let merchantStr = escapeCSV(expense.merchant.isEmpty ? "Expense" : expense.merchant)
            let categoryName = escapeCSV(categoryMap[expense.categoryId] ?? "Other")
            let amountStr = String(format: "%.2f", NSDecimalNumber(decimal: expense.decimalAmount).doubleValue)
            let paymentStr = escapeCSV(expense.paymentMethod ?? "Unknown")
            let notesStr = escapeCSV(expense.notes)

            csv += "\(dateStr),\(merchantStr),\(categoryName),\(amountStr),\(paymentStr),\(notesStr)\n"
        }

        return csv
    }

    /// Writes CSV data to a temporary file URL suitable for iOS ShareLink.
    static func generateCSVFileURL(expenses: [Expense], categories: [ExpenseCategory]) -> URL? {
        let csvContent = generateCSV(expenses: expenses, categories: categories)
        let filename = "ExpenseTracker_\(DateHelpers.displayMonth(for: Date()).replacingOccurrences(of: " ", with: "_")).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write CSV export file: \(error.localizedDescription)")
            return nil
        }
    }

    private static func escapeCSV(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }
}
