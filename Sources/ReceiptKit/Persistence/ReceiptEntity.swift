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
    public var rawText: String
    public var createdAt: Date
    public var imagePath: String?

    public init(
        id: UUID,
        merchant: String,
        date: Date?,
        total: Decimal,
        currencyCode: String,
        rawText: String,
        createdAt: Date,
        imagePath: String?
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

    public convenience init(_ receipt: Receipt) {
        self.init(
            id: receipt.id,
            merchant: receipt.merchant,
            date: receipt.date,
            total: receipt.total,
            currencyCode: receipt.currencyCode,
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
            rawText: rawText,
            createdAt: createdAt,
            imagePath: imagePath
        )
    }
}

public enum ReceiptSchema {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: ReceiptEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
