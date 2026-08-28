import Foundation

// MARK: - Parsed Expense Result

struct ParsedExpense {
    var amount: Decimal?
    var categoryName: String?
    var merchant: String?
    var date: Date?
    var paymentMethod: String?
}

// MARK: - Voice Expense Parser

enum VoiceExpenseParser {

    /// Parses a natural language transcript into structured expense fields.
    /// Examples:
    ///   "six point thirty five dollars on groceries at walmart, purchased today by credit card"
    ///   "i spent seventy three point nine nine dollar on dining at popeyes yesterday using debit card"
    static func parse(_ transcript: String) -> ParsedExpense {
        let text = transcript
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var result = ParsedExpense()
        result.amount = extractAmount(from: text)
        result.categoryName = extractCategory(from: text)
        result.merchant = extractMerchant(from: text)
        result.date = extractDate(from: text)
        result.paymentMethod = extractPaymentMethod(from: text)

        return result
    }

    // MARK: - Amount Extraction

    private static func extractAmount(from text: String) -> Decimal? {
        // Try numeric pattern first: "$6.35", "6.35 dollars", "73.99 dollar"
        let numericPatterns = [
            #"\$\s*(\d+\.?\d*)"#,
            #"(\d+\.?\d*)\s*dollars?"#,
            #"(\d+\.?\d*)\s*bucks?"#,
            #"spent\s+(\d+\.?\d*)"#,
            #"of\s+(\d+\.?\d*)"#,
        ]

        for pattern in numericPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchStr = String(text[match])
                let digits = matchStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                if let val = Decimal(string: digits), val > 0 {
                    return val
                }
            }
        }

        // Try word-number conversion: "six point thirty five"
        if let converted = convertWordNumbersToDecimal(in: text) {
            return converted
        }

        return nil
    }

    /// Converts spoken number words to a Decimal value
    /// Handles patterns like "six point thirty five", "seventy three point nine nine"
    private static func convertWordNumbersToDecimal(in text: String) -> Decimal? {
        let wordToNum: [String: Int] = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
            "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
            "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
            "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17,
            "eighteen": 18, "nineteen": 19, "twenty": 20, "thirty": 30,
            "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
            "eighty": 80, "ninety": 90, "hundred": 100
        ]

        // Find amount-related region: words before "dollar(s)", or after "spent", or after "$"
        let words = text.components(separatedBy: .whitespaces)

        // Find "dollar" or "dollars" index
        let dollarIdx = words.firstIndex(where: { $0.hasPrefix("dollar") })
        // Also try finding amount after "spent"
        let spentIdx = words.firstIndex(of: "spent")

        var numberWords: [String] = []

        if let dIdx = dollarIdx {
            // Collect number words before "dollar(s)"
            var i = dIdx - 1
            while i >= 0 {
                let w = words[i].trimmingCharacters(in: .punctuationCharacters)
                if wordToNum[w] != nil || w == "point" || w == "and" {
                    numberWords.insert(w, at: 0)
                    i -= 1
                } else {
                    break
                }
            }
        } else if let sIdx = spentIdx {
            // Collect number words after "spent"
            var i = sIdx + 1
            while i < words.count {
                let w = words[i].trimmingCharacters(in: .punctuationCharacters)
                if wordToNum[w] != nil || w == "point" || w == "and" {
                    numberWords.append(w)
                    i += 1
                } else {
                    break
                }
            }
        }

        guard !numberWords.isEmpty else { return nil }

        // Split by "point" for integer and decimal parts
        let pointIdx = numberWords.firstIndex(of: "point")
        let integerWords: [String]
        let decimalWords: [String]

        if let pIdx = pointIdx {
            integerWords = Array(numberWords[..<pIdx])
            decimalWords = Array(numberWords[(pIdx + 1)...])
        } else {
            integerWords = numberWords
            decimalWords = []
        }

        let intPart = wordsToNumber(integerWords, wordToNum: wordToNum)
        let decPart = wordsToDecimalPart(decimalWords, wordToNum: wordToNum)

        let total = Decimal(intPart) + decPart
        return total > 0 ? total : nil
    }

    private static func wordsToNumber(_ words: [String], wordToNum: [String: Int]) -> Int {
        var result = 0
        var current = 0
        for w in words {
            let cleaned = w.trimmingCharacters(in: .punctuationCharacters)
            guard let val = wordToNum[cleaned] else { continue }
            if val == 100 {
                current = (current == 0 ? 1 : current) * 100
            } else {
                current += val
            }
        }
        result += current
        return result
    }

    private static func wordsToDecimalPart(_ words: [String], wordToNum: [String: Int]) -> Decimal {
        guard !words.isEmpty else { return 0 }
        // Convert each word to its digit and concatenate as decimal string
        var digits = ""
        for w in words {
            let cleaned = w.trimmingCharacters(in: .punctuationCharacters)
            if let val = wordToNum[cleaned] {
                if val < 10 {
                    digits += "\(val)"
                } else {
                    // For "thirty five" -> "35"
                    digits += "\(val)"
                }
            }
        }
        if digits.isEmpty { return 0 }
        return Decimal(string: "0.\(digits)") ?? 0
    }

    // MARK: - Category Extraction

    private static let categoryKeywords: [(keywords: [String], name: String)] = [
        (["coffee", "cafe", "latte", "cappuccino", "espresso"], "Coffee"),
        (["groceries", "grocery", "supermarket"], "Groceries"),
        (["dining", "restaurant", "food", "eat", "meal", "lunch", "dinner", "breakfast", "brunch"], "Dining & Food"),
        (["transport", "transit", "bus", "subway", "train", "uber", "lyft", "taxi", "cab", "ride"], "Transport"),
        (["presto", "ttc"], "PRESTO"),
        (["shopping", "clothes", "clothing", "shoes", "fashion"], "Shopping"),
        (["subscription", "netflix", "spotify", "youtube", "streaming"], "Subscriptions"),
        (["textbook", "book", "school", "tuition", "education", "university"], "Textbooks & School"),
        (["rent", "housing", "apartment", "lease"], "Rent & Housing"),
        (["entertainment", "movie", "game", "gaming", "concert", "event"], "Entertainment"),
        (["utility", "utilities", "bill", "bills", "hydro", "electricity", "internet", "phone"], "Utilities & Bills"),
        (["health", "fitness", "gym", "medicine", "pharmacy", "doctor", "dental"], "Health & Fitness"),
    ]

    private static func extractCategory(from text: String) -> String? {
        // Try "on <category>" pattern first
        if let onMatch = text.range(of: #"(?:on|for)\s+([a-z &]+?)(?:\s+at\s|\s+from\s|\s*,|\s+purchased|\s+bought|\s+paid|\s+using|\s+by\s|\s+with\s|$)"#, options: .regularExpression) {
            let segment = String(text[onMatch])
                .replacingOccurrences(of: #"^(?:on|for)\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+(?:at|from|purchased|bought|paid|using|by|with)\s*.*$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespaces)

            // Match segment against category keywords
            for entry in categoryKeywords {
                for keyword in entry.keywords {
                    if segment.contains(keyword) {
                        return entry.name
                    }
                }
            }
        }

        // Fallback: scan entire text for category keywords
        for entry in categoryKeywords {
            for keyword in entry.keywords {
                if text.contains(keyword) {
                    return entry.name
                }
            }
        }

        return nil
    }

    // MARK: - Merchant Extraction

    private static func extractMerchant(from text: String) -> String? {
        // Pattern: "at <merchant>" or "from <merchant>"
        let patterns = [
            #"(?:at|from)\s+([a-zA-Z0-9' &\-]+?)(?:\s*,|\s+purchased|\s+bought|\s+paid|\s+today|\s+yesterday|\s+on\s|\s+using|\s+by\s|\s+with\s|$)"#,
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                var segment = String(text[match])
                // Remove the "at " or "from " prefix
                segment = segment.replacingOccurrences(of: #"^(?:at|from)\s+"#, with: "", options: .regularExpression)
                // Remove trailing context words
                segment = segment.replacingOccurrences(of: #"\s*(?:,|purchased|bought|paid|today|yesterday|on|using|by|with)\s*.*$"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !segment.isEmpty {
                    // Capitalize first letter of each word
                    return segment.capitalized
                }
            }
        }

        return nil
    }

    // MARK: - Date Extraction

    private static func extractDate(from text: String) -> Date? {
        let calendar = Calendar.current

        if text.contains("today") {
            return Date()
        }

        if text.contains("yesterday") {
            return calendar.date(byAdding: .day, value: -1, to: Date())
        }

        if text.contains("day before yesterday") || text.contains("two days ago") {
            return calendar.date(byAdding: .day, value: -2, to: Date())
        }

        // Try NSDataDetector for specific dates
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = detector?.firstMatch(in: text, options: [], range: range), let date = match.date {
            return date
        }

        return nil
    }

    // MARK: - Payment Method Extraction

    private static let paymentKeywords: [(keywords: [String], method: String)] = [
        (["credit card", "credit"], "Credit"),
        (["debit card", "debit"], "Debit"),
        (["cash"], "Cash"),
        (["e-transfer", "etransfer", "e transfer", "interac"], "E-Transfer"),
        (["presto card", "presto"], "PRESTO"),
        (["forex card", "forex"], "Forex Card"),
    ]

    private static func extractPaymentMethod(from text: String) -> String? {
        // Look after "using", "by", "with", "paid by", "paid with", "paid using"
        let paymentRegion: String
        if let match = text.range(of: #"(?:using|by|with|paid\s+(?:by|with|using))\s+(.+)$"#, options: .regularExpression) {
            paymentRegion = String(text[match])
        } else {
            paymentRegion = text
        }

        // Check longer phrases first to avoid "credit" matching before "credit card"
        let sortedKeywords = paymentKeywords.sorted { a, b in
            let aMax = a.keywords.map(\.count).max() ?? 0
            let bMax = b.keywords.map(\.count).max() ?? 0
            return aMax > bMax
        }

        for entry in sortedKeywords {
            for keyword in entry.keywords.sorted(by: { $0.count > $1.count }) {
                if paymentRegion.contains(keyword) {
                    return entry.method
                }
            }
        }

        return nil
    }
}
