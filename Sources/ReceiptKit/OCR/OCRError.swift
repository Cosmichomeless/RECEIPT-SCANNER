import Foundation

public enum OCRError: Error, Equatable, Sendable, LocalizedError {
    /// The image could not be read (zero size or unsupported). Retrying needs a new scan.
    case invalidImage
    /// Vision ran but found no text. Recoverable: rescan with better light or framing.
    case noTextFound
    /// Vision failed while recognizing. Recoverable: retry.
    case recognitionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The scanned image could not be read."
        case .noTextFound:
            "No text was found. Try scanning again with better light."
        case .recognitionFailed(let reason):
            "Text recognition failed: \(reason)"
        }
    }

    /// Whether the user can reasonably retry (rescan or run again) without changing the app.
    public var isRecoverable: Bool { true }
}
