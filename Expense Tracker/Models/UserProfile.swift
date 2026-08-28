import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Sendable {
    let userId: String
    var displayName: String
    var email: String
    var currency: String
    var monthlyIncome: Double?
    var onboardingCompleted: Bool
    var createdAt: Date
    var enabledFields: [String]         // Optional expense fields the user has enabled

    var decimalMonthlyIncome: Decimal? {
        get {
            guard let income = monthlyIncome else { return nil }
            return Decimal(income)
        }
        set {
            if let newValue {
                monthlyIncome = NSDecimalNumber(decimal: newValue).doubleValue
            } else {
                monthlyIncome = nil
            }
        }
    }

    init(
        userId: String,
        displayName: String = "",
        email: String = "",
        currency: String = AppConstants.defaultCurrency,
        monthlyIncome: Decimal? = nil,
        onboardingCompleted: Bool = false,
        createdAt: Date = Date(),
        enabledFields: [String] = []
    ) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.currency = currency
        if let income = monthlyIncome {
            self.monthlyIncome = NSDecimalNumber(decimal: income).doubleValue
        } else {
            self.monthlyIncome = nil
        }
        self.onboardingCompleted = onboardingCompleted
        self.createdAt = createdAt
        self.enabledFields = enabledFields
    }
}
