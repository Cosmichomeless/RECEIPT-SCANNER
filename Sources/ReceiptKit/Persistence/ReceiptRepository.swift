import Foundation

/// Persistence boundary. Callers deal in `Receipt` values; storage details stay behind it.
public protocol ReceiptRepository: Sendable {
    func save(_ receipt: Receipt) async throws
    /// Newest first.
    func fetchAll() async throws -> [Receipt]
    func receipt(id: Receipt.ID) async throws -> Receipt?
    func delete(id: Receipt.ID) async throws
}
