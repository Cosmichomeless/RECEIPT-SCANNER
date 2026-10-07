import Foundation

/// A possible receipt total with the evidence behind its score.
public struct TotalCandidate: Equatable, Sendable {
    public let amount: Decimal
    public let lineIndex: Int
    public let score: Int
    public let lineText: String
}

/// Finds the receipt total by scoring every amount in the text. Expects normalized text,
/// where amounts are written `1234.56`.
public struct TotalParser: Sendable {
    public init() {}

    /// Minimum score for `parse` to answer: needs keyword evidence, not just a number.
    static let acceptanceThreshold = 25

    /// Best candidate, or `nil` when nothing is convincing (the user then fills it in).
    public func parse(_ text: NormalizedText) -> Decimal? {
        candidates(in: text).first { $0.score >= Self.acceptanceThreshold }?.amount
    }

    /// All candidates, best first. Ties go to the lower candidate on the page.
    public func candidates(in text: NormalizedText) -> [TotalCandidate] {
        let lines = text.lines
        var result: [TotalCandidate] = []
        for (position, line) in lines.enumerated() {
            let amounts = Self.amounts(in: line.text)
            guard !amounts.isEmpty else { continue }
            // With a keyword, the total is the last amount on the line ("TOTAL 3 ITEMS 84.37").
            let chosen = amounts.last!
            var score = Self.labelScore(for: line.text, previous: position > 0 ? lines[position - 1].text : nil)
            let labelled = score > 0
            score += Self.positionScore(position: position, count: lines.count)
            if line.text.contains(where: { "€$£¥".contains($0) }) || Self.hasCurrencyCode(line.text) { score += 5 }
            if !labelled { score -= 5 }
            result.append(TotalCandidate(amount: chosen, lineIndex: line.index, score: score, lineText: line.text))
        }
        result = Self.applyRelationships(result)
        return result
            .filter { $0.score > 0 }
            .sorted { ($0.score, $0.lineIndex) > ($1.score, $1.lineIndex) }
    }

    // MARK: - Labels

    /// Words that mark a line as NOT being the total. Checked before total keywords so that
    /// `SUBTOTAL` is not read as `TOTAL`.
    private static let excluded = [
        "SUBTOTAL", "SUB TOTAL", "SUB-TOTAL", "TAX", "VAT", "IVA", "IGIC", "DISCOUNT", "DESCUENTO",
        "CHANGE", "CAMBIO", "CASH", "EFECTIVO", "TENDER", "TIP", "PROPINA", "SAVINGS", "COUPON",
        "ENTREGADO", "RECIBIDO", "BASE IMPONIBLE",
    ]

    private static let strongKeywords = [
        "GRAND TOTAL", "AMOUNT DUE", "TOTAL DUE", "BALANCE DUE", "TOTAL A PAGAR", "A PAGAR",
        "IMPORTE TOTAL", "TOTAL AMOUNT", "TOTAL EUR", "TOTAL USD", "TOTAL GBP", "TOTAL €", "TOTAL $",
        "TOTAL £", "TO PAY",
    ]

    private static let weakKeywords = ["TOTAL", "AMOUNT", "IMPORTE", "BALANCE", "SUMA"]

    private static func labelScore(for text: String, previous: String?) -> Int {
        let upper = text.uppercased()
        // Excluded words win, so `TOTAL TAX` and `SUBTOTAL` are never totals.
        if excluded.contains(where: { containsWord($0, in: upper) }) { return -60 }
        if strongKeywords.contains(where: { upper.contains($0) }) { return 60 }
        if weakKeywords.contains(where: { containsWord($0, in: upper) }) { return 45 }
        // A bare amount directly under a lone keyword line ("TOTAL" / "84.37").
        if let previous {
            let prev = previous.uppercased()
            let alone = amounts(in: previous).isEmpty
            if alone, strongKeywords.contains(where: { prev.contains($0) }) { return 40 }
            if alone, weakKeywords.contains(where: { containsWord($0, in: prev) }),
               !excluded.contains(where: { containsWord($0, in: prev) }) {
                return 30
            }
        }
        return 0
    }

    private static func containsWord(_ word: String, in upper: String) -> Bool {
        var searchRange = upper.startIndex..<upper.endIndex
        while let found = upper.range(of: word, range: searchRange) {
            let before = found.lowerBound == upper.startIndex ? nil : upper[upper.index(before: found.lowerBound)]
            let after = found.upperBound == upper.endIndex ? nil : upper[found.upperBound]
            let boundaryBefore = before.map { !$0.isLetter } ?? true
            let boundaryAfter = after.map { !$0.isLetter } ?? true
            if boundaryBefore && boundaryAfter { return true }
            searchRange = found.upperBound..<upper.endIndex
        }
        return false
    }

    // MARK: - Position and relationships

    /// Totals sit in the lower part of a receipt, but not at the very end (card slips, URLs).
    private static func positionScore(position: Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let ratio = Double(position) / Double(count - 1)
        switch ratio {
        case 0.5..<0.95: return 10
        case 0.95...: return 5
        case 0.25..<0.5: return 4
        default: return 0
        }
    }

    /// With a subtotal on the page, the total is expected to equal subtotal − discount + tax.
    /// Candidates well below that are penalized; exact matches are boosted.
    private static func applyRelationships(_ candidates: [TotalCandidate]) -> [TotalCandidate] {
        guard let subtotal = candidates.first(where: { containsSubtotal($0.lineText) })?.amount else {
            return candidates
        }
        let tax = candidates.first { containsTax($0.lineText) }?.amount ?? 0
        let discount = candidates.first { containsDiscount($0.lineText) }?.amount ?? 0
        let expected = subtotal - discount + tax
        return candidates.map { candidate in
            var score = candidate.score
            if candidate.score > 0, !containsSubtotal(candidate.lineText) {
                if candidate.amount == expected { score += 25 }
                else if candidate.amount < subtotal - discount { score -= 40 }
            }
            return TotalCandidate(amount: candidate.amount, lineIndex: candidate.lineIndex,
                                  score: score, lineText: candidate.lineText)
        }
    }

    private static func containsDiscount(_ text: String) -> Bool {
        let upper = text.uppercased()
        return ["DISCOUNT", "DESCUENTO", "SAVINGS", "COUPON"].contains { containsWord($0, in: upper) }
    }

    private static func containsSubtotal(_ text: String) -> Bool {
        let upper = text.uppercased()
        return ["SUBTOTAL", "SUB TOTAL", "SUB-TOTAL"].contains { upper.contains($0) }
    }

    private static func containsTax(_ text: String) -> Bool {
        let upper = text.uppercased()
        return ["TAX", "VAT", "IVA"].contains { containsWord($0, in: upper) }
    }

    // MARK: - Amount extraction

    private static let amountPattern = try! NSRegularExpression(pattern: #"(?<![0-9.])\d+\.\d{2}(?![0-9])(?!\.\d)"#)
    private static let currencyCodes = ["EUR", "USD", "GBP", "CHF", "JPY", "MXN", "CAD", "AUD"]

    static func amounts(in text: String) -> [Decimal] {
        let range = NSRange(text.startIndex..., in: text)
        return amountPattern.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).flatMap { Decimal(string: String(text[$0]), locale: Locale(identifier: "en_US_POSIX")) }
        }
    }

    private static func hasCurrencyCode(_ text: String) -> Bool {
        let upper = text.uppercased()
        return currencyCodes.contains { containsWord($0, in: upper) }
    }
}
