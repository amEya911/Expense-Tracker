import Foundation
import FirebaseFirestore

struct Budget: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    let userId: String
    var monthYear: String               // "2026-08" — partition key
    var overallLimit: Double?           // nil means no overall budget set
    var categoryLimits: [String: Double] // categoryId -> limit amount
    var createdAt: Date
    var updatedAt: Date

    var decimalOverallLimit: Decimal? {
        get {
            guard let limit = overallLimit else { return nil }
            return Decimal(limit)
        }
        set {
            if let newValue {
                overallLimit = NSDecimalNumber(decimal: newValue).doubleValue
            } else {
                overallLimit = nil
            }
        }
    }

    func decimalLimit(for categoryId: String) -> Decimal? {
        guard let limit = categoryLimits[categoryId] else { return nil }
        return Decimal(limit)
    }

    init(
        id: String? = nil,
        userId: String,
        monthYear: String = DateHelpers.monthYearKey(),
        overallLimit: Decimal? = nil,
        categoryLimits: [String: Decimal] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.monthYear = monthYear
        if let limit = overallLimit {
            self.overallLimit = NSDecimalNumber(decimal: limit).doubleValue
        } else {
            self.overallLimit = nil
        }
        self.categoryLimits = categoryLimits.mapValues { NSDecimalNumber(decimal: $0).doubleValue }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
