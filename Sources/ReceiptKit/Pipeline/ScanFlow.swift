import CoreGraphics
import Observation

/// Drives scan → process → review. Pure state machine over `CaptureOutcome`, so it can
/// be tested without a camera.
@MainActor
@Observable
public final class ScanFlow {
    public enum State {
        case idle
        case scanning
        case processing
        case review(ParsedReceipt, image: CGImage)
        case failed(message: String)
    }

    public private(set) var state: State = .idle
    /// Set when saving fails; the review state is kept so nothing the user typed is lost.
    public private(set) var saveError: String?
    private let processor: ReceiptProcessor
    private let repository: any ReceiptRepository

    public init(processor: ReceiptProcessor, repository: any ReceiptRepository = InMemoryReceiptRepository()) {
        self.processor = processor
        self.repository = repository
    }

    public func startScan() {
        state = .scanning
    }

    /// Cancelling returns to idle and stores nothing.
    public func handle(_ outcome: CaptureOutcome) async {
        switch outcome {
        case .cancelled:
            state = .idle
        case .failed(let error):
            state = .failed(message: Self.message(for: error))
        case .captured(let image):
            state = .processing
            do {
                state = .review(try await processor.process(image), image: image)
            } catch {
                state = .failed(message: error.localizedDescription)
            }
        }
    }

    /// Saves the corrected receipt and returns to idle. Returns `false`, staying in review,
    /// when the draft is incomplete or storage fails.
    @discardableResult
    public func save(_ draft: ReceiptDraft) async -> Bool {
        guard let receipt = draft.makeReceipt() else { return false }
        do {
            try await repository.save(receipt)
            saveError = nil
            state = .idle
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    public func reset() {
        saveError = nil
        state = .idle
    }

    private static func message(for error: CaptureError) -> String {
        switch error {
        case .cameraUnavailable:
            "The document camera is not available on this device."
        case .scannerFailed(let reason):
            "Scanning failed: \(reason)"
        }
    }
}
