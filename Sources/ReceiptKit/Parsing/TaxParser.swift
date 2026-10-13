import Foundation

/// Reads base, rate and VAT amount from normalized text (amounts written `1234.56`).
///
/// Understands the layouts printed on Spanish receipts, and the equivalent German and French
/// words:
/// - one row per rate: `IVA 10%  BASE 6,36  CUOTA 0,64`, or a header (`IVA  BASE  CUOTA`)
///   followed by rows (`10%  6,36  0,64`);
/// - separate lines: `BASE IMPONIBLE 10,00` and `IVA 21% 2,10` or `TOTAL IVA 2,10`;
/// - `SUBTOTAL` + `TAX`, accepted as base only when base + tax equals the total;
/// - `IVA INCLUIDO 10%` with a total and no figures, where base and tax are computed and
///   marked as estimated.
///
/// A row is only accepted when its tax equals base × rate, so a stray amount is not mistaken
/// for a tax figure.
public struct TaxParser: Sendable {
    public init() {}

    /// Rates printed in Spain (4, 10, 21), Germany (7, 19) and France (5.5, 10, 20), among others.
    static let knownRates: [Decimal] = [4, 5, Decimal(string: "5.5")!, 7, 10, 19, 20, 21]

    public func parse(_ text: NormalizedText, total: Decimal?) -> TaxBreakdown? {
        let lines = text.lines.map(Line.init)
        let breakdown = Self.fromRows(lines) ?? Self.fromSeparateLines(lines, total: total)
        guard let breakdown, !breakdown.isEmpty else { return nil }
        return breakdown
    }

    // MARK: - Line analysis

    private struct Line {
        let upper: String
        /// Percentage written on the line (`21%`, `10 %`), if any.
        let rate: Decimal?
        /// Amounts on the line, without the percentage.
        let amounts: [Decimal]

        init(_ line: NormalizedLine) {
            let ns = line.text as NSString
            var rate: Decimal?
            var withoutRate = line.text
            let matches = Self.ratePattern.matches(in: line.text, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                let written = ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ".")
                let value = Decimal(string: written, locale: Locale(identifier: "en_US_POSIX"))
                if let value, value > 0, value <= 30 { rate = value }
                if let range = Range(match.range, in: withoutRate) { withoutRate.replaceSubrange(range, with: " ") }
            }
            self.rate = rate
            self.amounts = TotalParser.amounts(in: withoutRate)
            self.upper = line.text.uppercased()
        }

        private static let ratePattern = try! NSRegularExpression(pattern: #"(?<![0-9.,])(\d{1,2}(?:[.,]\d{1,2})?) ?%"#)

        func has(_ words: [String]) -> Bool { words.contains { TotalParser.containsWord($0, in: upper) } }

        var hasTaxWord: Bool { has(TaxParser.taxWords) }
        var hasBaseWord: Bool { has(TaxParser.baseWords) }
        var hasQuotaWord: Bool { has(TaxParser.quotaWords) }
        var isTaxLine: Bool { hasTaxWord || hasBaseWord || hasQuotaWord }
        var isSubtotal: Bool { upper.contains("SUBTOTAL") || upper.contains("SUB TOTAL") || upper.contains("SUB-TOTAL") }
        var isIncluded: Bool {
            ["INCLUIDO", "INCLUIDA", "INCLUDED", "INCL", "INKL", "TTC", "INC."].contains { upper.contains($0) }
        }
    }

    private static let taxWords = ["IVA", "I.V.A", "IGIC", "VAT", "TVA", "MWST", "MWST.", "UST", "TAX", "IMPUESTO", "IMPUESTOS"]
    private static let baseWords = ["BASE IMPONIBLE", "BASE IMP", "BASE", "B.I.", "NETO", "NETTO", "TOTAL HT", "MONTANT HT", "TAXABLE"]
    private static let quotaWords = ["CUOTA"]

    // MARK: - One row per rate

    private struct Row {
        let rate: Decimal
        let base: Decimal
        let tax: Decimal
    }

    private static func fromRows(_ lines: [Line]) -> TaxBreakdown? {
        var rows: [Row] = []
        var inTable = false
        for line in lines {
            if line.isTaxLine, line.amounts.isEmpty { inTable = true; continue }
            let qualifies = line.isTaxLine || (inTable && line.rate != nil)
            guard qualifies, line.amounts.count >= 2, let row = findRow(in: line.amounts, rate: line.rate) else {
                inTable = false
                continue
            }
            rows.append(row)
            inTable = true
        }
        guard !rows.isEmpty else { return nil }
        let rates = Set(rows.map(\.rate))
        return TaxBreakdown(
            base: rows.reduce(0) { $0 + $1.base },
            rate: rates.count == 1 ? rates.first : nil,
            amount: rows.reduce(0) { $0 + $1.tax }
        )
    }

    /// The (base, tax) pair on the line whose tax equals base × rate, closest first.
    private static func findRow(in amounts: [Decimal], rate: Decimal?) -> Row? {
        var best: (row: Row, error: Decimal, order: Int)?
        for i in amounts.indices {
            for j in amounts.indices where i != j {
                let base = amounts[i], tax = amounts[j]
                guard base > 0, tax > 0, tax < base else { continue }
                for candidate in rate.map({ [$0] }) ?? knownRates {
                    let error = abs(base * candidate / 100 - tax)
                    guard error <= TaxBreakdown.tolerance else { continue }
                    let order = i < j ? 0 : 1
                    if best == nil || (error, order) < (best!.error, best!.order) {
                        best = (Row(rate: candidate, base: base, tax: tax), error, order)
                    }
                }
            }
        }
        return best?.row
    }

    // MARK: - Separate lines

    private static func fromSeparateLines(_ lines: [Line], total: Decimal?) -> TaxBreakdown? {
        var taxEntries: [(amount: Decimal, rate: Decimal?, isTotal: Bool)] = []
        var rateHint: Decimal?
        var included = false
        for line in lines where line.hasTaxWord || line.hasQuotaWord {
            if line.hasTaxWord, let rate = line.rate, rateHint == nil { rateHint = rate }
            if line.isIncluded { included = true }
            guard line.amounts.count == 1, let amount = line.amounts.first, amount > 0 else { continue }
            let isTotal = line.upper.contains("TOTAL") || line.hasQuotaWord
            taxEntries.append((amount, line.rate, isTotal))
        }

        guard !taxEntries.isEmpty else {
            return estimated(rate: rateHint, included: included, total: total)
        }

        let tax: Decimal
        var rate: Decimal?
        if taxEntries.count == 1 {
            tax = taxEntries[0].amount
            rate = taxEntries[0].rate ?? rateHint
        } else if let totalEntry = taxEntries.first(where: \.isTotal) {
            tax = totalEntry.amount
            rate = totalEntry.rate
        } else {
            tax = taxEntries.reduce(0) { $0 + $1.amount }
            let rates = Set(taxEntries.compactMap(\.rate))
            rate = rates.count == 1 ? rates.first : nil
        }

        var base = baseAmount(in: lines)
        if base == nil, let total, let subtotal = subtotalAmount(in: lines), near(subtotal + tax, total) {
            base = subtotal
        }
        if base == nil, let total, total > tax {
            let remainder = total - tax
            if let rate, near(remainder * rate / 100, tax) { base = remainder }
            else if rate == nil, inferRate(base: remainder, tax: tax) != nil { base = remainder }
        }
        if rate == nil, let base { rate = inferRate(base: base, tax: tax) }
        return TaxBreakdown(base: base, rate: rate, amount: tax)
    }

    /// Sum of the single-amount lines labelled as base (one per rate when several rates are printed).
    private static func baseAmount(in lines: [Line]) -> Decimal? {
        let amounts = lines
            .filter { $0.hasBaseWord && !$0.hasTaxWord && !$0.hasQuotaWord && $0.amounts.count == 1 }
            .compactMap(\.amounts.first)
        return amounts.isEmpty ? nil : amounts.reduce(0, +)
    }

    private static func subtotalAmount(in lines: [Line]) -> Decimal? {
        lines.first { $0.isSubtotal && $0.amounts.count == 1 }?.amounts.first
    }

    /// `IVA INCLUIDO 10%` with a total: base = total / (1 + rate), tax = the rest.
    private static func estimated(rate: Decimal?, included: Bool, total: Decimal?) -> TaxBreakdown? {
        guard let rate else { return nil }
        guard included, let total, total > 0 else { return TaxBreakdown(rate: rate) }
        let base = round2(total / (1 + rate / 100))
        return TaxBreakdown(base: base, rate: rate, amount: total - base, isEstimated: true)
    }

    /// The known rate whose tax on `base` matches `tax` to the cent.
    private static func inferRate(base: Decimal, tax: Decimal) -> Decimal? {
        guard base > 0 else { return nil }
        return knownRates.first { near(base * $0 / 100, tax) }
    }

    private static func near(_ a: Decimal, _ b: Decimal) -> Bool { abs(a - b) <= TaxBreakdown.tolerance }

    private static func round2(_ value: Decimal) -> Decimal {
        var input = value, output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }
}
