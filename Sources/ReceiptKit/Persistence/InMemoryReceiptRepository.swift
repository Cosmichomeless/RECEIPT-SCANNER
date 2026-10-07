import Foundation

/// Keeps receipts for the lifetime of the process. Used by tests and previews.
public actor InMemoryReceiptRepository: ReceiptRepository {
    private var receipts: [Receipt.ID: Receipt] = [:]

    public init(_ initial: [Receipt] = []) {
        for receipt in initial { receipts[receipt.id] = receipt }
    }

    public func save(_ receipt: Receipt) async throws {
        receipts[receipt.id] = receipt
    }

    public func fetchAll() async throws -> [Receipt] {
        receipts.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func receipt(id: Receipt.ID) async throws -> Receipt? {
        receipts[id]
    }

    public func delete(id: Receipt.ID) async throws {
        receipts[id] = nil
    }
}
