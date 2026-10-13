import Foundation
import SwiftData

/// SwiftData storage form of `Receipt`. Reference type, tied to a `ModelContext`:
/// it stays inside the persistence layer and the rest of the app uses `Receipt`.
@Model
public final class ReceiptEntity {
    @Attribute(.unique) public var id: UUID
    public var merchant: String
    public var date: Date?
    public var total: Decimal
    public var currencyCode: String
    // Optional so existing stores migrate without a version step.
    public var taxBase: Decimal?
    public var taxRate: Decimal?
    public var taxAmount: Decimal?
    public var taxIsEstimated: Bool?
    public var taxID: String?
    public var rawText: String
    public var createdAt: Date
    public var imagePath: String?

    public init(
        id: UUID,
        merchant: String,
        date: Date?,
        total: Decimal,
        currencyCode: String,
        tax: TaxBreakdown = TaxBreakdown(),
        taxID: String? = nil,
        rawText: String,
        createdAt: Date,
        imagePath: String?
    ) {
        self.id = id
        self.merchant = merchant
        self.date = date
        self.total = total
        self.currencyCode = currencyCode
        self.taxBase = tax.base
        self.taxRate = tax.rate
        self.taxAmount = tax.amount
        self.taxIsEstimated = tax.isEstimated
        self.taxID = taxID
        self.rawText = rawText
        self.createdAt = createdAt
        self.imagePath = imagePath
    }

    public convenience init(_ receipt: Receipt) {
        self.init(
            id: receipt.id,
            merchant: receipt.merchant,
            date: receipt.date,
            total: receipt.total,
            currencyCode: receipt.currencyCode,
            tax: receipt.tax,
            taxID: receipt.taxID,
            rawText: receipt.rawText,
            createdAt: receipt.createdAt,
            imagePath: receipt.imagePath
        )
    }

    /// Copies the editable fields of `receipt`. `id` and `createdAt` never change.
    public func update(from receipt: Receipt) {
        merchant = receipt.merchant
        date = receipt.date
        total = receipt.total
        currencyCode = receipt.currencyCode
        taxBase = receipt.tax.base
        taxRate = receipt.tax.rate
        taxAmount = receipt.tax.amount
        taxIsEstimated = receipt.tax.isEstimated
        taxID = receipt.taxID
        rawText = receipt.rawText
        imagePath = receipt.imagePath
    }

    public var receipt: Receipt {
        Receipt(
            id: id,
            merchant: merchant,
            date: date,
            total: total,
            currencyCode: currencyCode,
            tax: TaxBreakdown(base: taxBase, rate: taxRate, amount: taxAmount, isEstimated: taxIsEstimated ?? false),
            taxID: taxID,
            rawText: rawText,
            createdAt: createdAt,
            imagePath: imagePath
        )
    }
}

public enum ReceiptSchema {
    /// `url` selects an on-disk store location (tests use it to simulate an app restart);
    /// `nil` uses the app's default store.
    public static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let configuration = if let url {
            ModelConfiguration(url: url)
        } else {
            ModelConfiguration(isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(for: ReceiptEntity.self, configurations: configuration)
    }
}
