import Foundation
import FirebaseFirestore
import SwiftUI

struct ExpenseCategory: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    let userId: String
    var name: String
    var icon: String                // SF Symbol name
    var colorHex: String            // Hex color string (without #)
    var sortOrder: Int
    var isDefault: Bool             // System-provided category
    var isArchived: Bool            // Soft-deleted

    var color: Color {
        Color(hex: colorHex)
    }

    init(
        id: String? = nil,
        userId: String,
        name: String,
        icon: String,
        colorHex: String,
        sortOrder: Int,
        isDefault: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.isArchived = isArchived
    }
}
