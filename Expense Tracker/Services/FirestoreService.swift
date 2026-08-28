import Foundation
import FirebaseCore
import FirebaseFirestore

@Observable
final class FirestoreService: Sendable {
    var db: Firestore {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return Firestore.firestore()
    }

    // MARK: - Collection References

    private func userDoc(_ userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    private func expensesCollection(_ userId: String) -> CollectionReference {
        userDoc(userId).collection("expenses")
    }

    private func categoriesCollection(_ userId: String) -> CollectionReference {
        userDoc(userId).collection("categories")
    }

    private func budgetsCollection(_ userId: String) -> CollectionReference {
        userDoc(userId).collection("budgets")
    }

    private func userProfileDoc(_ userId: String) -> DocumentReference {
        userDoc(userId).collection("profile").document("main")
    }

    // MARK: - Expenses

    func addExpense(_ expense: Expense) async throws -> String {
        guard !expense.userId.isEmpty else { return UUID().uuidString }
        let docRef = try expensesCollection(expense.userId).addDocument(from: expense)
        return docRef.documentID
    }

    func updateExpense(_ expense: Expense) async throws {
        guard let id = expense.id, !expense.userId.isEmpty else { return }
        try expensesCollection(expense.userId).document(id).setData(from: expense, merge: true)
    }

    func deleteExpense(userId: String, expenseId: String) async throws {
        guard !userId.isEmpty && !expenseId.isEmpty else { return }
        print("[FirestoreService] Deleting expense doc: \(expenseId) for user: \(userId)")
        try await expensesCollection(userId).document(expenseId).delete()
    }

    func getExpense(userId: String, expenseId: String) async throws -> Expense? {
        guard !userId.isEmpty && !expenseId.isEmpty else { return nil }
        let snapshot = try await expensesCollection(userId).document(expenseId).getDocument()
        if var expense = try? snapshot.data(as: Expense.self) {
            expense.id = snapshot.documentID
            return expense
        }
        return nil
    }

    func getExpenses(
        userId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        categoryId: String? = nil,
        limit: Int? = nil
    ) async throws -> [Expense] {
        guard !userId.isEmpty else { return [] }
        var query: Query = expensesCollection(userId).order(by: "date", descending: true)

        if let startDate {
            query = query.whereField("date", isGreaterThanOrEqualTo: startDate)
        }
        if let endDate {
            query = query.whereField("date", isLessThanOrEqualTo: endDate)
        }
        if let categoryId {
            query = query.whereField("categoryId", isEqualTo: categoryId)
        }
        if let limit {
            query = query.limit(to: limit)
        }

        do {
            let snapshot = try await query.getDocuments()
            return snapshot.documents.compactMap { doc -> Expense? in
                if var expense = try? doc.data(as: Expense.self) {
                    expense.id = doc.documentID
                    return expense
                }
                return nil
            }
        } catch {
            print("[FirestoreService] getExpenses error: \(error.localizedDescription)")
            return []
        }
    }

    func getRecentMerchants(userId: String, limit: Int = 10) async throws -> [String] {
        let expenses = try await getExpenses(userId: userId, limit: 50)
        var seen = Set<String>()
        var merchants: [String] = []
        for expense in expenses where !expense.merchant.isEmpty {
            let trimmed = expense.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = trimmed.lowercased()
            if !lowered.isEmpty && !seen.contains(lowered) {
                seen.insert(lowered)
                merchants.append(trimmed)
                if merchants.count >= limit { break }
            }
        }
        return merchants
    }

    // MARK: - Categories

    func getCategories(userId: String) async throws -> [ExpenseCategory] {
        guard !userId.isEmpty else {
            return defaultCategoriesFallback(userId: "")
        }

        do {
            let snapshot = try await categoriesCollection(userId)
                .order(by: "sortOrder")
                .getDocuments()
            var fetched = snapshot.documents.compactMap { try? $0.data(as: ExpenseCategory.self) }
            
            if fetched.isEmpty {
                // Categories collection is empty: seed immediately
                return try await seedDefaultCategories(userId: userId)
            }

            // Ensure PRESTO category exists in older accounts
            if !fetched.contains(where: { $0.name.lowercased().contains("presto") }) {
                if let prestoDef = DefaultCategory.all.first(where: { $0.name.lowercased().contains("presto") }) {
                    let docRef = categoriesCollection(userId).document()
                    let prestoCat = ExpenseCategory(
                        id: docRef.documentID,
                        userId: userId,
                        name: prestoDef.name,
                        icon: prestoDef.icon,
                        colorHex: prestoDef.color,
                        sortOrder: prestoDef.sortOrder,
                        isDefault: true
                    )
                    try? docRef.setData(from: prestoCat)
                    fetched.append(prestoCat)
                    return fetched.sorted(by: { $0.sortOrder < $1.sortOrder })
                }
            }

            return fetched
        } catch {
            print("[FirestoreService] getCategories failed: \(error.localizedDescription). Using defaults.")
            Task { try? await self.seedDefaultCategories(userId: userId) }
            return defaultCategoriesFallback(userId: userId)
        }
    }

    func addCategory(_ category: ExpenseCategory) async throws -> String {
        guard !category.userId.isEmpty else { return UUID().uuidString }
        let docRef = try categoriesCollection(category.userId).addDocument(from: category)
        return docRef.documentID
    }

    func updateCategory(_ category: ExpenseCategory) async throws {
        guard let id = category.id, !category.userId.isEmpty else { return }
        try categoriesCollection(category.userId).document(id).setData(from: category, merge: true)
    }

    func deleteCategory(userId: String, categoryId: String) async throws {
        guard !userId.isEmpty && !categoryId.isEmpty else { return }
        var category = try await categoriesCollection(userId).document(categoryId).getDocument().data(as: ExpenseCategory.self)
        category.isArchived = true
        try await updateCategory(category)
    }

    func seedDefaultCategories(userId: String) async throws -> [ExpenseCategory] {
        guard !userId.isEmpty else { return defaultCategoriesFallback(userId: "") }

        var seeded: [ExpenseCategory] = []
        let batch = db.batch()

        for def in DefaultCategory.all {
            let docRef = categoriesCollection(userId).document()
            let cat = ExpenseCategory(
                id: docRef.documentID,
                userId: userId,
                name: def.name,
                icon: def.icon,
                colorHex: def.color,
                sortOrder: def.sortOrder,
                isDefault: true
            )
            try batch.setData(from: cat, forDocument: docRef)
            seeded.append(cat)
        }

        try await batch.commit()
        return seeded
    }

    private func defaultCategoriesFallback(userId: String) -> [ExpenseCategory] {
        DefaultCategory.all.enumerated().map { index, def in
            ExpenseCategory(
                id: "default_\(index)",
                userId: userId,
                name: def.name,
                icon: def.icon,
                colorHex: def.color,
                sortOrder: def.sortOrder,
                isDefault: true
            )
        }
    }

    // MARK: - Budgets

    func getBudget(userId: String, monthYear: String) async throws -> Budget? {
        guard !userId.isEmpty else { return nil }
        do {
            let doc = try await budgetsCollection(userId).document(monthYear).getDocument()
            if doc.exists {
                return try? doc.data(as: Budget.self)
            }
            return nil
        } catch {
            print("[FirestoreService] getBudget error: \(error.localizedDescription)")
            return nil
        }
    }

    func saveBudget(_ budget: Budget) async throws {
        guard !budget.userId.isEmpty else { return }
        var b = budget
        b.id = budget.monthYear
        try budgetsCollection(budget.userId).document(budget.monthYear).setData(from: b, merge: true)
    }

    // MARK: - Monthly Spending Summary & PRESTO Deductions

    /// Total cash outflow for the month. Excludes payments made with PRESTO card to prevent double-counting.
    func getMonthlySpending(userId: String, monthYear: String) async throws -> Decimal {
        let date = DateHelpers.startOfMonth(for: dateFromMonthYear(monthYear))
        let endDate = DateHelpers.endOfMonth(for: date)

        let expenses = try await getExpenses(userId: userId, startDate: date, endDate: endDate)
        // Deductions from PRESTO card balance were already counted when PRESTO was topped up
        return expenses
            .filter { !$0.isPrestoPayment }
            .reduce(Decimal.zero) { $0 + $1.decimalAmount }
    }

    func getSpendingByCategory(userId: String, monthYear: String) async throws -> [String: Decimal] {
        let date = DateHelpers.startOfMonth(for: dateFromMonthYear(monthYear))
        let endDate = DateHelpers.endOfMonth(for: date)

        let expenses = try await getExpenses(userId: userId, startDate: date, endDate: endDate)
        var breakdown: [String: Decimal] = [:]
        for expense in expenses {
            breakdown[expense.categoryId, default: .zero] += expense.decimalAmount
        }
        return breakdown
    }

    /// Calculate PRESTO stored value card metrics: (currentBalance, totalLoaded, totalUsed)
    func getPrestoMetrics(userId: String) async throws -> (balance: Decimal, totalLoaded: Decimal, totalUsed: Decimal) {
        guard !userId.isEmpty else { return (.zero, .zero, .zero) }
        let allExpenses = try await getExpenses(userId: userId)
        let categories = try await getCategories(userId: userId)
        
        let catMap = Dictionary(uniqueKeysWithValues: categories.compactMap { cat in
            cat.id.map { ($0, cat.name.lowercased()) }
        })

        var totalLoaded: Decimal = .zero
        var totalUsed: Decimal = .zero

        for expense in allExpenses {
            let catName = catMap[expense.categoryId] ?? ""
            let isPrestoCategory = catName.contains("presto") || expense.categoryId.lowercased().contains("presto")
            let isPrestoMerchant = expense.merchant.lowercased().contains("presto")

            // Top up is any expense in PRESTO category (or merchant containing PRESTO) not paid via PRESTO card tap
            if (isPrestoCategory || isPrestoMerchant) && !expense.isPrestoPayment {
                totalLoaded += expense.decimalAmount
            }
            
            // Usage is any transit tap paid with PRESTO
            if expense.isPrestoPayment {
                totalUsed += expense.decimalAmount
            }
        }

        let balance = max(totalLoaded - totalUsed, .zero)
        return (balance, totalLoaded, totalUsed)
    }

    // MARK: - Profile

    func getProfile(userId: String) async throws -> UserProfile? {
        guard !userId.isEmpty else { return nil }
        let doc = try await userProfileDoc(userId).getDocument()
        return try? doc.data(as: UserProfile.self)
    }

    func saveProfile(_ profile: UserProfile) async throws {
        guard !profile.userId.isEmpty else { return }
        try userProfileDoc(profile.userId).setData(from: profile, merge: true)
    }

    // MARK: - Account Deletion

    func deleteAllUserData(userId: String) async throws {
        guard !userId.isEmpty else { return }
        let subcollections = ["expenses", "categories", "budgets", "recurring", "profile"]
        for name in subcollections {
            let snapshot = try await userDoc(userId).collection(name).getDocuments()
            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
        try await userDoc(userId).delete()
    }

    // MARK: - Helpers

    private func dateFromMonthYear(_ monthYear: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: monthYear) ?? Date()
    }
}
