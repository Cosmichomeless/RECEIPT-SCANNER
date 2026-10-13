import Foundation

/// A field the parser could not resolve with confidence and that the user must review.
public enum ParsingIssue: Hashable, Sendable {
    case missingMerchant
    case missingDate
    /// The text holds a date that can be read in more than one way.
    case ambiguousDate(candidates: [CalendarDate])
    case missingTotal
    case missingCurrency
    /// The marks on the receipt fit several currencies; the user picks one.
    case ambiguousCurrency(candidates: [String])
    /// Base plus VAT does not give the total. Either figure may be misread.
    case taxMismatch
}

/// Structured output of the parser. Unknown fields are `nil`, never guessed.
public struct ParsedReceipt: Equatable, Sendable {
    public var merchant: String?
    public var date: CalendarDate?
    public var total: Decimal?
    /// ISO 4217 code, for example `EUR`.
    public var currencyCode: String?
    /// VAT figures, when the receipt shows any.
    public var tax: TaxBreakdown?
    /// Tax number of the merchant (NIF, CIF or NIE), without separators.
    public var merchantTaxID: String?
    /// Untouched OCR text, kept so results stay traceable.
    public var rawText: String
    public var issues: [ParsingIssue]

    public init(
        merchant: String? = nil,
        date: CalendarDate? = nil,
        total: Decimal? = nil,
        currencyCode: String? = nil,
        tax: TaxBreakdown? = nil,
        merchantTaxID: String? = nil,
        rawText: String,
        issues: [ParsingIssue] = []
    ) {
        self.merchant = merchant
        self.date = date
        self.total = total
        self.currencyCode = currencyCode
        self.tax = tax
        self.merchantTaxID = merchantTaxID
        self.rawText = rawText
        self.issues = issues
    }
}
