/// What happens to the scanned image once the receipt is saved.
/// See `docs/privacy-and-storage.md`.
public enum ImageRetention: Sendable {
    /// Default. Only the extracted fields and raw text are stored.
    case discard
    /// The user explicitly chose to keep the scan; it is stored locally and its
    /// relative path goes in `Receipt.imagePath`.
    case keep

    public static let `default`: ImageRetention = .discard
}
