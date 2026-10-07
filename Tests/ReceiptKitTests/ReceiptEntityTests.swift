import Foundation
import SwiftData
import Testing
@testable import ReceiptKit

@Suite struct ReceiptEntityTests {
    private let sample = Receipt(
        merchant: "Northline Hardware",
        date: Date(timeIntervalSince1970: 1_790_000_000),
        total: Decimal(string: "84.37")!,
        currencyCode: "EUR",
        rawText: "TOTAL 84.37",
        createdAt: Date(timeIntervalSince1970: 1_790_000_100),
        imagePath: nil
    )

    @Test func roundTripsEveryField() throws {
        let container = try ReceiptSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(ReceiptEntity(sample))
        try context.save()

        let stored = try ModelContext(container).fetch(FetchDescriptor<ReceiptEntity>())
        #expect(stored.map(\.receipt) == [sample])
    }

    @Test func keepsOptionalFieldsEmpty() throws {
        var receipt = sample
        receipt.date = nil
        receipt.imagePath = nil
        #expect(ReceiptEntity(receipt).receipt == receipt)
    }

    @Test func updateKeepsIdentityAndCreationDate() {
        let entity = ReceiptEntity(sample)
        var edited = sample
        edited.merchant = "Corrected Name"
        edited.total = 10
        entity.update(from: edited)
        #expect(entity.id == sample.id)
        #expect(entity.createdAt == sample.createdAt)
        #expect(entity.merchant == "Corrected Name")
        #expect(entity.total == 10)
    }
}
