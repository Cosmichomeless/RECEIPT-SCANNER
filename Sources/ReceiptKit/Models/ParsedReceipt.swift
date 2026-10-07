import Foundation

/// A field the parser could not resolve with confidence and that the user must review.
public enum ParsingIssue: Hashable, Sendable {
    case missingMerchant
    case missingDate
    /// The text holds a date that can be read in more than one way.
    case ambiguousDate(candidates: [CalendarDate])
    case missingTotal
    case missingCurrency
}

/// Structured output of the parser. Unknown fields are `nil`, never guessed.
public struct ParsedReceipt: Equatable, Sendable {
    public var merchant: String?
    public var date: CalendarDate?
    public var total: Decimal?
    /// ISO 4217 code, for example `EUR`.
    public var currencyCode: String?
    /// Untouched OCR text, kept so results stay traceable.
    public var rawText: String
    public var issues: [ParsingIssue]

    public init(
        merchant: String? = nil,
        date: CalendarDate? = nil,
        total: Decimal? = nil,
        currencyCode: String? = nil,
        rawText: String,
        issues: [ParsingIssue] = []
    ) {
        self.merchant = merchant
        self.date = date
        self.total = total
        self.currencyCode = currencyCode
        self.rawText = rawText
        self.issues = issues
    }
}
