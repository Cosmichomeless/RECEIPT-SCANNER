import Foundation

/// What the review screen edits: the parsed values as text and flags the user can change,
/// validated before a `Receipt` is created.
public struct ReceiptDraft: Equatable, Sendable {
    public var merchant: String
    /// `nil` when the date is unknown or the user chose not to set one.
    public var date: CalendarDate?
    /// Amount exactly as typed, for example `84.37` or `84,37`.
    public var totalText: String
    public var currencyCode: String
    /// VAT fields as typed. Empty when the receipt has none; all optional.
    public var taxBaseText: String
    public var taxRateText: String
    public var taxAmountText: String
    /// NIF, CIF or NIE of the merchant. Empty when unknown.
    public var taxID: String
    /// The tax figures were computed from the total and the rate, not read from the receipt.
    public var taxIsEstimated: Bool
    public let rawText: String
    /// Fields the parser could not fill with confidence, so the UI can highlight them.
    public let issues: [ParsingIssue]
    /// Dates to offer when the parser found several readings.
    public let dateSuggestions: [CalendarDate]
    public let currencySuggestions: [String]

    public init(_ parsed: ParsedReceipt) {
        merchant = parsed.merchant ?? ""
        date = parsed.date
        totalText = parsed.total.map { Self.format($0) } ?? ""
        currencyCode = parsed.currencyCode ?? ""
        taxBaseText = parsed.tax?.base.map { Self.format($0) } ?? ""
        taxRateText = parsed.tax?.rate.map { Self.format($0) } ?? ""
        taxAmountText = parsed.tax?.amount.map { Self.format($0) } ?? ""
        taxID = parsed.merchantTaxID ?? ""
        taxIsEstimated = parsed.tax?.isEstimated ?? false
        rawText = parsed.rawText
        issues = parsed.issues
        dateSuggestions = parsed.issues.compactMap {
            if case .ambiguousDate(let candidates) = $0 { candidates } else { nil }
        }.flatMap { $0 }
        currencySuggestions = parsed.issues.compactMap {
            if case .ambiguousCurrency(let candidates) = $0 { candidates } else { nil }
        }.flatMap { $0 }
    }

    public enum Problem: Hashable, Sendable {
        case missingMerchant, missingTotal, invalidTotal, missingCurrency, invalidCurrency
        case invalidTaxBase, invalidTaxRate, invalidTaxAmount
    }

    /// Everything that blocks saving. Empty means `makeReceipt` succeeds.
    public var problems: [Problem] {
        var result: [Problem] = []
        if merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.missingMerchant) }
        let trimmedTotal = totalText.trimmingCharacters(in: .whitespaces)
        if trimmedTotal.isEmpty { result.append(.missingTotal) }
        else if total == nil { result.append(.invalidTotal) }
        let code = currencyCode.trimmingCharacters(in: .whitespaces)
        if code.isEmpty { result.append(.missingCurrency) }
        else if !Self.isCurrencyCode(code) { result.append(.invalidCurrency) }
        if !taxBaseText.isBlank, Self.parseAmount(taxBaseText) == nil { result.append(.invalidTaxBase) }
        if !taxRateText.isBlank, Self.parseRate(taxRateText) == nil { result.append(.invalidTaxRate) }
        if !taxAmountText.isBlank, Self.parseAmount(taxAmountText) == nil { result.append(.invalidTaxAmount) }
        return result
    }

    /// The VAT figures that were typed or detected, already validated.
    public var tax: TaxBreakdown {
        TaxBreakdown(
            base: Self.parseAmount(taxBaseText),
            rate: Self.parseRate(taxRateText),
            amount: Self.parseAmount(taxAmountText),
            isEstimated: taxIsEstimated
        )
    }

    /// `true` when base and VAT are both set and do not add up to the total. A warning, not a blocker:
    /// the user may know better than the arithmetic (a tip, a rounding in the printed ticket).
    public var taxMismatch: Bool { !tax.isConsistent(withTotal: total) }

    public var canSave: Bool { problems.isEmpty }

    /// The typed amount, accepting `.` or `,` as the decimal mark. Negative and zero are rejected.
    public var total: Decimal? { Self.parseAmount(totalText) }

    /// The validated receipt, or `nil` while `problems` is not empty.
    public func makeReceipt(calendar: Calendar = .current, now: Date = Date()) -> Receipt? {
        guard canSave, let total else { return nil }
        return Receipt(
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date?.date(in: calendar),
            total: total,
            currencyCode: currencyCode.trimmingCharacters(in: .whitespaces).uppercased(),
            tax: tax,
            taxID: taxID.isBlank ? nil : taxID.trimmingCharacters(in: .whitespaces).uppercased(),
            rawText: rawText,
            createdAt: now
        )
    }

    // MARK: - Helpers

    static func isCurrencyCode(_ code: String) -> Bool {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }

    static func parseAmount(_ text: String) -> Decimal? {
        var value = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        let comma = value.lastIndex(of: ","), dot = value.lastIndex(of: ".")
        switch (comma, dot) {
        case let (c?, d?):
            // Both present: the later one is the decimal mark, the other groups thousands.
            let decimal = c > d ? "," : "."
            let group = c > d ? "." : ","
            value = value.replacingOccurrences(of: group, with: "").replacingOccurrences(of: decimal, with: ".")
        case (.some, nil):
            // A lone comma followed by exactly three digits could be grouping, but amounts typed
            // by hand with a comma are decimals ("84,37", "1,5").
            value = value.replacingOccurrences(of: ",", with: ".")
        default: break
        }
        guard value.allSatisfy({ $0.isASCIIDigit || $0 == "." }), value.filter({ $0 == "." }).count <= 1,
              let amount = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")), amount > 0
        else { return nil }
        return amount
    }

    /// A percentage between 0 and 100, `.` or `,` as the decimal mark. Zero is a valid rate.
    static func parseRate(_ text: String) -> Decimal? {
        let value = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !value.isEmpty, value.allSatisfy({ $0.isASCIIDigit || $0 == "." }), value.filter({ $0 == "." }).count <= 1,
              let rate = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")), rate <= 100
        else { return nil }
        return rate
    }

    static func format(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
