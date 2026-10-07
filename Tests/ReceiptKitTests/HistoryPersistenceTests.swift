import Foundation
import Testing
@testable import ReceiptKit

@Suite struct HistoryPersistenceTests {
    private func receipt(_ merchant: String, createdAt: Date, total: String = "9.50") -> Receipt {
        Receipt(
            merchant: merchant, date: createdAt, total: Decimal(string: total)!, currencyCode: "EUR",
            rawText: "raw \(merchant)", createdAt: createdAt
        )
    }

    private func storeURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString).store")
    }

    @Test func savedReceiptsSurviveRestart() async throws {
        let url = storeURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let old = receipt("OLD", createdAt: Date(timeIntervalSince1970: 1_000))
        let new = receipt("NEW", createdAt: Date(timeIntervalSince1970: 2_000), total: "84.37")

        do {
            let repository = SwiftDataReceiptRepository(modelContainer: try ReceiptSchema.makeContainer(url: url))
            try await repository.save(old)
            try await repository.save(new)
        }
        // A new container on the same file is what the app does on the next launch.
        let reopened = SwiftDataReceiptRepository(modelContainer: try ReceiptSchema.makeContainer(url: url))
        let all = try await reopened.fetchAll()
        #expect(all.map(\.merchant) == ["NEW", "OLD"])
        #expect(all.first?.total == Decimal(string: "84.37"))
        #expect(try await reopened.receipt(id: old.id) == old)
    }

    @Test func savingSameIdUpdatesInsteadOfDuplicating() async throws {
        let repository = SwiftDataReceiptRepository(modelContainer: try ReceiptSchema.makeContainer(inMemory: true))
        var value = receipt("CAFE", createdAt: Date(timeIntervalSince1970: 1_000))
        try await repository.save(value)
        value.merchant = "CAFE LUNA"
        try await repository.save(value)
        let all = try await repository.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.merchant == "CAFE LUNA")
    }

    @Test func deleteRemovesReceipt() async throws {
        let repository = SwiftDataReceiptRepository(modelContainer: try ReceiptSchema.makeContainer(inMemory: true))
        let value = receipt("GONE", createdAt: Date(timeIntervalSince1970: 1_000))
        try await repository.save(value)
        try await repository.delete(id: value.id)
        #expect(try await repository.fetchAll().isEmpty)
        #expect(try await repository.receipt(id: value.id) == nil)
        try await repository.delete(id: value.id)
    }

    @MainActor
    @Test func historyStoreListsAndDeletes() async throws {
        let a = receipt("A", createdAt: Date(timeIntervalSince1970: 1_000))
        let b = receipt("B", createdAt: Date(timeIntervalSince1970: 2_000))
        let store = HistoryStore(repository: InMemoryReceiptRepository([a, b]))
        await store.reload()
        #expect(store.receipts.map(\.merchant) == ["B", "A"])
        await store.delete(b.id)
        #expect(store.receipts.map(\.merchant) == ["A"])
    }
}
