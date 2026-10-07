import Foundation
import SwiftData

/// SwiftData-backed history. Runs on its own actor with a private `ModelContext`, so
/// `ReceiptEntity` objects never leave it: callers only see `Receipt` values.
@ModelActor
public actor SwiftDataReceiptRepository: ReceiptRepository {
    public func save(_ receipt: Receipt) throws {
        if let existing = try entity(id: receipt.id) {
            existing.update(from: receipt)
        } else {
            modelContext.insert(ReceiptEntity(receipt))
        }
        try modelContext.save()
    }

    public func fetchAll() throws -> [Receipt] {
        let descriptor = FetchDescriptor<ReceiptEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.receipt)
    }

    public func receipt(id: Receipt.ID) throws -> Receipt? {
        try entity(id: id)?.receipt
    }

    public func delete(id: Receipt.ID) throws {
        guard let existing = try entity(id: id) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    private func entity(id: Receipt.ID) throws -> ReceiptEntity? {
        var descriptor = FetchDescriptor<ReceiptEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
