import Observation

/// Receipts shown on the history screen. Loads from the repository on demand, so what the
/// user sees is always what is stored.
@MainActor
@Observable
public final class HistoryStore {
    public private(set) var receipts: [Receipt] = []
    public private(set) var loadError: String?
    private let repository: any ReceiptRepository

    public init(repository: any ReceiptRepository) {
        self.repository = repository
    }

    public func reload() async {
        do {
            receipts = try await repository.fetchAll()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    public func delete(_ id: Receipt.ID) async {
        do {
            try await repository.delete(id: id)
            receipts.removeAll { $0.id == id }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}
