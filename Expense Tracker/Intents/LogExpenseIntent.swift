import Foundation
import AppIntents
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description: IntentDescription = "Logs an expense with amount, merchant, category, and payment method via Siri."
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Expense Details", description: "Expense description, e.g. 15 dollars on Coffee at Tim Hortons by Debit")
    var details: String?

    @Parameter(title: "Amount", description: "The amount spent (e.g. 15 or 15 dollars)")
    var amount: String?

    @Parameter(title: "Category", description: "The category (e.g. Groceries, Dining, Coffee, Transport)")
    var category: String?

    @Parameter(title: "Merchant", description: "The store or merchant name (e.g. Starbucks, Walmart)")
    var merchant: String?

    @Parameter(title: "Payment Method", description: "Payment method used (e.g. Credit, Debit, Cash, PRESTO, Forex Card)")
    var paymentMethod: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var resolvedAmount: Decimal?
        var resolvedCategory: String?
        var resolvedMerchant: String?
        var resolvedPayment: String?

        // 1. Check if user provided initial full phrase or details
        let initialTokens = [details, amount, category, merchant, paymentMethod]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !initialTokens.isEmpty {
            let parsed = VoiceExpenseParser.parse(initialTokens)
            resolvedAmount = parsed.amount
            resolvedCategory = parsed.categoryName
            resolvedMerchant = parsed.merchant
            resolvedPayment = parsed.paymentMethod
        }

        // 2. Validate & request Amount if missing
        if resolvedAmount == nil || (resolvedAmount ?? 0) <= 0 {
            let spokenAmount = try await $amount.requestValue(IntentDialog("How much did you spend?"))
            let parsed = VoiceExpenseParser.parse(spokenAmount)
            if let amt = parsed.amount, amt > 0 {
                resolvedAmount = amt
            } else {
                let digits = spokenAmount.replacingOccurrences(of: #"[^0-9.]"#, with: "", options: .regularExpression)
                resolvedAmount = Decimal(string: digits)
            }

            // Capture any extra information spoken during the amount prompt
            if resolvedCategory == nil, let cat = parsed.categoryName { resolvedCategory = cat }
            if resolvedMerchant == nil, let m = parsed.merchant { resolvedMerchant = m }
            if resolvedPayment == nil, let p = parsed.paymentMethod { resolvedPayment = p }
        }

        guard let finalAmount = resolvedAmount, finalAmount > 0 else {
            return .result(dialog: IntentDialog("I could not understand the amount. Please try again."))
        }

        // 3. Validate & request Category if missing or unrecognized
        var matchedCat = matchCategory(resolvedCategory)
        if matchedCat == nil {
            let spokenCategory = try await $category.requestValue(IntentDialog("I could not find the category, please say it again. (For example: Groceries, Dining, Coffee, or Transport)"))
            let parsed = VoiceExpenseParser.parse(spokenCategory)
            matchedCat = matchCategory(parsed.categoryName ?? spokenCategory)
        }

        guard let finalCategory = matchedCat else {
            return .result(dialog: IntentDialog("I still could not recognize the category. Please try again."))
        }

        // 4. Validate & request Merchant if missing
        if resolvedMerchant == nil || (resolvedMerchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let spokenMerchant = try await $merchant.requestValue(IntentDialog("Where did you spend it? What is the merchant name?"))
            let cleaned = spokenMerchant.replacingOccurrences(of: #"(?i)^(at|from|to)\s+"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            resolvedMerchant = cleaned.isEmpty ? spokenMerchant.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
        }

        guard let finalMerchant = resolvedMerchant, !finalMerchant.isEmpty else {
            return .result(dialog: IntentDialog("I could not get the merchant name. Please try again."))
        }

        // 5. Validate & resolve Payment Method (defaults to Credit if not specified)
        let finalPayment = matchPaymentMethod(resolvedPayment) ?? "Credit"

        // 6. Firebase Authentication Check
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        guard let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty else {
            return .result(dialog: IntentDialog("Please open Expense Tracker and sign in first to log your expenses."))
        }

        // 7. Save to Firestore
        let firestoreService = FirestoreService()
        do {
            let userCategories = try? await firestoreService.getCategories(userId: currentUserId)
            let matchedCatId = userCategories?.first(where: { $0.name.lowercased() == finalCategory.lowercased() })?.id ?? "cat_\(finalCategory.lowercased())"

            let newExpense = Expense(
                userId: currentUserId,
                amount: finalAmount,
                categoryId: matchedCatId,
                merchant: finalMerchant.capitalized,
                date: Date(),
                notes: "Logged via Siri",
                paymentMethod: finalPayment
            )

            _ = try await firestoreService.addExpense(newExpense)

            let formattedAmount = CurrencyFormatter.format(finalAmount)
            return .result(dialog: IntentDialog("Logged \(formattedAmount) on \(finalCategory) at \(finalMerchant.capitalized) using \(finalPayment)."))
        } catch {
            return .result(dialog: IntentDialog("Could not save the expense: \(error.localizedDescription)"))
        }
    }

    // MARK: - Category Matcher

    private func matchCategory(_ input: String?) -> String? {
        guard let input = input?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return nil
        }

        let categoryRules: [(keywords: [String], name: String)] = [
            (["coffee", "cafe", "latte", "cappuccino", "starbucks", "tim hortons", "espresso"], "Coffee"),
            (["groceries", "grocery", "supermarket", "walmart", "metro", "loblaws", "costco", "market", "no frills", "food basics"], "Groceries"),
            (["dining", "dining & food", "food", "restaurant", "lunch", "dinner", "breakfast", "meal", "popeyes", "chipotle", "mcdonalds", "takeout", "burger", "pizza", "subway", "eats"], "Dining & Food"),
            (["transport", "transit", "bus", "train", "uber", "lyft", "go train", "ride", "taxi", "cab"], "Transport"),
            (["presto", "ttc", "transit card"], "PRESTO"),
            (["shopping", "clothes", "clothing", "shoes", "amazon", "uniqlo", "mall", "zara", "h&m"], "Shopping"),
            (["subscription", "subscriptions", "netflix", "spotify", "chatgpt", "apple music", "youtube", "icloud"], "Subscriptions"),
            (["textbooks", "textbook", "school", "books", "tuition", "bookstore", "course", "university"], "Textbooks & School"),
            (["rent", "rent & housing", "housing", "apartment", "dorm", "lease", "residence"], "Rent & Housing"),
            (["entertainment", "movie", "cinema", "games", "gaming", "concert", "show", "theatre"], "Entertainment"),
            (["utilities", "utility", "bills", "bill", "hydro", "internet", "phone bill", "wifi", "enbridge", "rogers", "bell"], "Utilities & Bills"),
            (["health", "health & fitness", "fitness", "gym", "pharmacy", "medicine", "doctor", "dentist", "shoppers drug mart"], "Health & Fitness"),
            (["other", "general", "misc", "miscellaneous"], "Other")
        ]

        for rule in categoryRules {
            for kw in rule.keywords {
                if input.contains(kw) {
                    return rule.name
                }
            }
        }

        return nil
    }

    // MARK: - Payment Method Matcher

    private func matchPaymentMethod(_ input: String?) -> String? {
        guard let input = input?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return nil
        }

        if input.contains("credit") { return "Credit" }
        if input.contains("debit") { return "Debit" }
        if input.contains("cash") { return "Cash" }
        if input.contains("e-transfer") || input.contains("etransfer") || input.contains("transfer") || input.contains("interac") { return "E-Transfer" }
        if input.contains("presto") { return "PRESTO" }
        if input.contains("forex") { return "Forex Card" }

        return nil
    }
}
