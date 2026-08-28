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
    var enabledFields: [String]
    var avatarIcon: String?
    var avatarColorHex: String?
    var avatarUrl: String?

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
        enabledFields: [String] = [],
        avatarIcon: String? = "person.crop.circle.fill",
        avatarColorHex: String? = "00C48C",
        avatarUrl: String? = nil
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
        self.avatarIcon = avatarIcon ?? "person.crop.circle.fill"
        self.avatarColorHex = avatarColorHex ?? "00C48C"
        self.avatarUrl = avatarUrl
    }

    enum CodingKeys: String, CodingKey {
        case userId, displayName, email, currency, monthlyIncome, onboardingCompleted, createdAt, enabledFields, avatarIcon, avatarColorHex, avatarUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        self.email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? AppConstants.defaultCurrency
        self.monthlyIncome = try container.decodeIfPresent(Double.self, forKey: .monthlyIncome)
        self.onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.enabledFields = try container.decodeIfPresent([String].self, forKey: .enabledFields) ?? []
        self.avatarIcon = try container.decodeIfPresent(String.self, forKey: .avatarIcon) ?? "person.crop.circle.fill"
        self.avatarColorHex = try container.decodeIfPresent(String.self, forKey: .avatarColorHex) ?? "00C48C"
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }
}
