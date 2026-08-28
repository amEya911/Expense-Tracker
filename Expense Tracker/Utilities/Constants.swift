import SwiftUI

enum AppConstants {
    static let appName = "Expense Tracker"
    static let defaultCurrency = "CAD"
    static let currencySymbol = "$"
    static let maxRecentTransactions = 5
    static let maxRecentMerchants = 10
}

// MARK: - Design System Colors
extension Color {
    static let appAccent = Color(hex: "00C48C")
    static let appWarning = Color(hex: "FF6B6B")
    static let appSecondaryText = Color.secondary

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension ShapeStyle where Self == Color {
    static var appAccent: Color { Color.appAccent }
    static var appWarning: Color { Color.appWarning }
}

// MARK: - Default Categories
struct DefaultCategory: Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let color: String
    let sortOrder: Int

    static let all: [DefaultCategory] = [
        DefaultCategory(name: "Coffee", icon: "cup.and.saucer.fill", color: "A2845E", sortOrder: 0),
        DefaultCategory(name: "Groceries", icon: "cart.fill", color: "34C759", sortOrder: 1),
        DefaultCategory(name: "Dining & Food", icon: "fork.knife", color: "FF9500", sortOrder: 2),
        DefaultCategory(name: "Transport", icon: "tram.fill", color: "007AFF", sortOrder: 3),
        DefaultCategory(name: "PRESTO", icon: "tram.circle.fill", color: "00C48C", sortOrder: 4),
        DefaultCategory(name: "Shopping", icon: "bag.fill", color: "FF2D55", sortOrder: 5),
        DefaultCategory(name: "Subscriptions", icon: "repeat", color: "FF6B6B", sortOrder: 6),
        DefaultCategory(name: "Textbooks & School", icon: "book.fill", color: "5856D6", sortOrder: 7),
        DefaultCategory(name: "Rent & Housing", icon: "house.fill", color: "AF52DE", sortOrder: 8),
        DefaultCategory(name: "Entertainment", icon: "gamecontroller.fill", color: "30B0C7", sortOrder: 9),
        DefaultCategory(name: "Utilities & Bills", icon: "bolt.fill", color: "FFCC00", sortOrder: 10),
        DefaultCategory(name: "Health & Fitness", icon: "heart.fill", color: "FF3B30", sortOrder: 11),
        DefaultCategory(name: "Other", icon: "ellipsis.circle.fill", color: "8E8E93", sortOrder: 12),
    ]
}

// MARK: - Category Suggestions
enum CategorySuggestions {
    static func defaultMerchants(for categoryName: String) -> [String] {
        let name = categoryName.lowercased()
        if name.contains("presto") {
            return ["PRESTO Auto-Load", "PRESTO App Reload", "Shoppers PRESTO", "Station Vending", "Online Top-Up"]
        } else if name.contains("transport") || name.contains("transit") {
            return ["Subway", "Bus", "Streetcar / Tram", "GO Train", "TTC", "Uber", "UP Express", "Bike Share"]
        } else if name.contains("coffee") {
            return ["Tim Hortons", "Starbucks", "Second Cup", "Balzac's", "Pilot Coffee", "Aroma"]
        } else if name.contains("grocer") {
            return ["Metro", "No Frills", "Loblaws", "T&T Supermarket", "Farm Boy", "Walmart", "Longo's"]
        } else if name.contains("dining") || name.contains("food") || name.contains("restaurant") {
            return ["McDonald's", "Chipotle", "Osmow's", "A&W", "Subway (Food)", "Popeyes", "Pizza Pizza"]
        } else if name.contains("textbook") || name.contains("school") || name.contains("education") {
            return ["UofT Bookstore", "Campus Bookstore", "Amazon", "Chegg", "Printing / Library"]
        } else if name.contains("subscription") {
            return ["Spotify", "Netflix", "Apple Music", "YouTube Premium", "ChatGPT", "iCloud", "Prime"]
        } else if name.contains("shopping") {
            return ["Amazon", "Winners", "Uniqlo", "H&M", "Sephora", "Dollarama", "Apple Store"]
        } else if name.contains("rent") || name.contains("housing") {
            return ["Rent / Landlord", "Residence / Dorm", "Hydro", "Laundry", "Tenant Insurance"]
        } else if name.contains("utilit") || name.contains("bill") {
            return ["Rogers", "Bell", "Fido", "Freedom Mobile", "Toronto Hydro", "Enbridge"]
        } else if name.contains("health") || name.contains("fitness") {
            return ["Shoppers Drug Mart", "Rexall", "GoodLife Fitness", "Planet Fitness", "Campus Gym"]
        } else if name.contains("entertain") {
            return ["Cineplex", "Steam", "PlayStation", "Nintendo", "Rec Room", "Concert / Event"]
        } else {
            return ["Tim Hortons", "Metro", "TTC", "Amazon", "Starbucks"]
        }
    }

    static func paymentMethods(for categoryName: String) -> [String] {
        let name = categoryName.lowercased()
        if name.contains("presto") {
            // Loading PRESTO is paid with card/cash/bank
            return ["Credit", "Debit", "Cash", "E-Transfer", "Forex Card"]
        } else if name.contains("transport") || name.contains("transit") {
            // Using Transport can be paid via PRESTO card or directly with credit/debit/cash/forex
            return ["PRESTO", "Credit", "Debit", "Cash", "E-Transfer", "Forex Card"]
        } else {
            return ["Credit", "Debit", "Cash", "E-Transfer", "Forex Card"]
        }
    }
}
