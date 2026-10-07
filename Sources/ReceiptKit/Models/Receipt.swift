import Foundation

/// A validated receipt as saved to history.
public struct Receipt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var merchant: String
    public var date: Date?
    public var total: Decimal
    /// ISO 4217 code, for example `EUR`.
    public var currencyCode: String
    public var rawText: String
    public let createdAt: Date
    /// Relative path of the retained scan, if the user chose to keep it.
    public var imagePath: String?

    public init(
        id: UUID = UUID(),
        merchant: String,
        date: Date?,
        total: Decimal,
        currencyCode: String,
        rawText: String,
        createdAt: Date = Date(),
        imagePath: String? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.date = date
        self.total = total
        self.currencyCode = currencyCode
        self.rawText = rawText
        self.createdAt = createdAt
        self.imagePath = imagePath
    }
}
