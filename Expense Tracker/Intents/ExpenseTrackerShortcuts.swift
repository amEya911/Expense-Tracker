import Foundation
import AppIntents

struct ExpenseTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Log an expense with \(.applicationName)",
                "Log an expense using \(.applicationName)",
                "Log expense in \(.applicationName)",
                "In \(.applicationName) log an expense",
                "In \(.applicationName) track an expense",
                "Track an expense in \(.applicationName)",
                "Track spending in \(.applicationName)",
                "Track spending with \(.applicationName)",
                "Record an expense in \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "plus.circle.fill"
        )
    }
}
