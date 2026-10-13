import Foundation

/// Writes receipts as CSV for a spreadsheet or an accountant.
///
/// - Columns: `date` (ISO `yyyy-MM-dd`), `merchant`, `tax_id`, `base`, `vat_rate`, `vat`, `total`,
///   `currency`, `category`. Unknown values are left empty.
/// - Regional format: where the locale writes decimals with a comma, the separator is `;` and amounts
///   use a comma, which is what Excel expects in those regions. Elsewhere it is `,` and `.`.
/// - Fields are quoted when they contain the separator, a quote or a line break (RFC 4180). Text that
///   starts with `=`, `+`, `-`, `@` or a tab is prefixed with `'` so a spreadsheet cannot run it as a formula.
/// - `data(for:)` starts with a UTF-8 byte order mark, so Excel reads accents correctly.
public struct CSVExporter: Sendable {
    public static let columns = ["date", "merchant", "tax_id", "base", "vat_rate", "vat", "total", "currency", "category"]

    public let separator: Character
    private let locale: Locale
    private let calendar: Calendar

    public init(locale: Locale = .current, calendar: Calendar = .current) {
        self.locale = locale
        self.calendar = calendar
        self.separator = locale.decimalSeparator == "," ? ";" : ","
    }

    public func data(for receipts: [Receipt]) -> Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(csv(for: receipts).utf8)
    }

    public func csv(for receipts: [Receipt]) -> String {
        var rows = [Self.columns.map { escape($0) }.joined(separator: String(separator))]
        for receipt in receipts {
            let fields: [String] = [
                receipt.date.map(isoDate) ?? "",
                text(receipt.merchant),
                text(receipt.taxID ?? ""),
                receipt.tax.base.map(amount) ?? "",
                receipt.tax.rate.map(rate) ?? "",
                receipt.tax.amount.map(amount) ?? "",
                amount(receipt.total),
                escape(receipt.currencyCode),
                "",
            ]
            rows.append(fields.joined(separator: String(separator)))
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Fields

    private func isoDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func amount(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(locale))
    }

    private func rate(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
    }

    /// Free text: neutralize formulas, then quote if needed.
    private func text(_ value: String) -> String {
        escape(Self.neutralizingFormula(value))
    }

    private func escape(_ field: String) -> String {
        let needsQuotes = field.contains(separator) || field.contains { $0 == "\"" || $0.isNewline }
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func neutralizingFormula(_ value: String) -> String {
        guard let first = value.first, "=+-@\t".contains(first) else { return value }
        return "'" + value
    }
}
