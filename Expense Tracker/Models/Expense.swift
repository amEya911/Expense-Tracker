import Foundation
import FirebaseFirestore

struct Expense: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var userId: String
    var amount: Double
    var currency: String
    var categoryId: String
    var merchant: String
    var date: Date
    var notes: String
    var paymentMethod: String?
    var tags: [String]
    var isRecurring: Bool
    var recurringId: String?
    var customFields: [String: AnyCodableValue]
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    var decimalAmount: Decimal {
        get { Decimal(amount) }
        set { amount = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    /// True if this expense was paid using a preloaded PRESTO card balance
    var isPrestoPayment: Bool {
        paymentMethod?.trimmingCharacters(in: .whitespaces).uppercased() == "PRESTO"
    }

    // MARK: - Convenience Initializer

    init(
        id: String? = nil,
        userId: String,
        amount: Decimal,
        currency: String = AppConstants.defaultCurrency,
        categoryId: String,
        merchant: String = "",
        date: Date = Date(),
        notes: String = "",
        paymentMethod: String? = nil,
        tags: [String] = [],
        isRecurring: Bool = false,
        recurringId: String? = nil,
        customFields: [String: AnyCodableValue] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self._id = DocumentID(wrappedValue: id)
        self.userId = userId
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currency = currency
        self.categoryId = categoryId
        self.merchant = merchant
        self.date = date
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.tags = tags
        self.isRecurring = isRecurring
        self.recurringId = recurringId
        self.customFields = customFields
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Safe Codable Decoding

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case amount
        case currency
        case categoryId
        case merchant
        case date
        case notes
        case paymentMethod
        case tags
        case isRecurring
        case recurringId
        case customFields
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self._id = try container.decode(DocumentID<String>.self, forKey: .id)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        self.amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0.0
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? AppConstants.defaultCurrency
        self.categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId) ?? ""
        self.merchant = try container.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        self.recurringId = try container.decodeIfPresent(String.self, forKey: .recurringId)
        self.customFields = try container.decodeIfPresent([String: AnyCodableValue].self, forKey: .customFields) ?? [:]
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
