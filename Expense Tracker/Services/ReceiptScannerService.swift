import Foundation
import UIKit
import Vision

struct ScannedReceipt {
    var amount: Decimal?
    var merchant: String?
    var date: Date?
    var rawText: String = ""
    var recognizedLines: [String] = []
}

@Observable
final class ReceiptScannerService {
    var isScanning: Bool = false
    var scannedReceipt: ScannedReceipt?
    var errorMessage: String?

    func scanReceipt(image: UIImage) async -> ScannedReceipt? {
        guard let cgImage = image.cgImage else {
            errorMessage = "Unable to process the image."
            return nil
        }

        isScanning = true
        errorMessage = nil

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                if let error {
                    DispatchQueue.main.async {
                        self.errorMessage = "OCR failed: \(error.localizedDescription)"
                        self.isScanning = false
                    }
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        self.errorMessage = "No text found on receipt."
                        self.isScanning = false
                    }
                    continuation.resume(returning: nil)
                    return
                }

                var lines: [String] = []
                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            lines.append(text)
                        }
                    }
                }

                let parsed = self.parseReceiptLines(lines)
                DispatchQueue.main.async {
                    self.scannedReceipt = parsed
                    self.isScanning = false
                }
                continuation.resume(returning: parsed)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to scan image: \(error.localizedDescription)"
                        self.isScanning = false
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func parseReceiptLines(_ lines: [String]) -> ScannedReceipt {
        var receipt = ScannedReceipt()
        receipt.recognizedLines = lines
        receipt.rawText = lines.joined(separator: "\n")

        guard !lines.isEmpty else { return receipt }

        // 1. Extract Merchant (typically in the first 4 non-empty lines)
        receipt.merchant = extractMerchant(from: lines)

        // 2. Extract Total Amount
        receipt.amount = extractTotalAmount(from: lines)

        // 3. Extract Date
        receipt.date = extractDate(from: lines)

        return receipt
    }

    private func extractMerchant(from lines: [String]) -> String? {
        let excludedWords = [
            "welcome", "receipt", "invoice", "order", "table", "guest", "server", "cashier",
            "tel", "phone", "fax", "www", "http", "store", "tax", "hst", "gst", "pst", "subtotal"
        ]

        let topLines = Array(lines.prefix(5))
        for line in topLines {
            let lower = line.lowercased()
            let containsExcluded = excludedWords.contains { lower.contains($0) }
            let containsDigits = line.rangeOfCharacter(from: .decimalDigits) != nil

            // Merchant names are usually letters only and not address/phone lines
            if !containsExcluded && !containsDigits && line.count >= 3 && line.count <= 35 {
                return cleanMerchantName(line)
            }
        }

        // Fallback: first line if valid length
        if let first = lines.first, first.count >= 3 && first.count <= 35 {
            return cleanMerchantName(first)
        }

        return nil
    }

    private func cleanMerchantName(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: #"[^a-zA-Z0-9' &\-]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .capitalized
    }

    private func extractTotalAmount(from lines: [String]) -> Decimal? {
        let totalKeywords = [
            "total", "grand total", "total due", "amount due", "balance due", "total amount",
            "amount paid", "cad total", "total cad", "cad$", "subtotal", "payment"
        ]

        var foundAmounts: [Decimal] = []

        // Search specifically near total keywords first
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            for keyword in totalKeywords {
                if lower.contains(keyword) {
                    // Look for price on the same line
                    if let price = extractPrice(from: line) {
                        return price
                    }
                    // Look for price on the subsequent line
                    if index + 1 < lines.count, let price = extractPrice(from: lines[index + 1]) {
                        return price
                    }
                }
            }

            // Also collect all valid prices across the entire receipt
            if let price = extractPrice(from: line) {
                foundAmounts.append(price)
            }
        }

        // If no explicit "total" label matched, pick the largest price on the receipt (excluding abnormal outliers)
        let validAmounts = foundAmounts.filter { $0 > 0 && $0 < 10000 }
        return validAmounts.max()
    }

    private func extractPrice(from text: String) -> Decimal? {
        // Pattern: $12.34 or 12.34 or 12,34
        let pattern = #"\$?\s*([0-9]+[.,][0-9]{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        // Take the last price mentioned on the line (common on receipts: "Item $4.99 Total $4.99")
        if let lastMatch = matches.last {
            var matchStr = nsString.substring(with: lastMatch.range(at: 1))
            matchStr = matchStr.replacingOccurrences(of: ",", with: ".")
            if let dec = Decimal(string: matchStr), dec > 0 {
                return dec
            }
        }
        return nil
    }

    private func extractDate(from lines: [String]) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

        for line in lines {
            let nsString = line as NSString
            let range = NSRange(location: 0, length: nsString.length)
            if let match = detector?.firstMatch(in: line, options: [], range: range), let date = match.date {
                // Ensure date is within a plausible range (not in the future, not older than 1 year)
                if date <= Date() && date >= Calendar.current.date(byAdding: .year, value: -1, to: Date())! {
                    return date
                }
            }
        }

        return nil
    }
}
