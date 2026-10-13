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
    /// Increments after each successful save so screens can refresh their lists.
    public private(set) var savedCount = 0
    /// Stage timings of the most recent scan, for diagnostics.
    public private(set) var lastTimings: ProcessingTimings?
    /// Longest side, in pixels, of the image kept while the user reviews. The review screen shows a
    /// small thumbnail, so holding the full-resolution capture (about 48 MB for 12 MP) would only
    /// cost memory. OCR still reads the full capture.
    public static let reviewImageMaxDimension = 1200
    private let processor: ReceiptProcessor
    private let repository: any ReceiptRepository

    public init(processor: ReceiptProcessor, repository: any ReceiptRepository = InMemoryReceiptRepository()) {
        self.processor = processor
        self.repository = repository
    }

    public func startScan() {
        state = .scanning
    }

    /// Cancelling returns to idle and stores nothing. While a capture is being processed any other
    /// outcome is ignored, so a second delivery cannot start a second recognition on top of the first.
    public func handle(_ outcome: CaptureOutcome) async {
        if case .processing = state { return }
        switch outcome {
        case .cancelled:
            state = .idle
        case .failed(let error):
            state = .failed(message: Self.message(for: error))
        case .captured(let image):
            state = .processing
            do {
                let (receipt, timings) = try await processor.processMeasured(image)
                lastTimings = timings
                state = .review(receipt, image: ImageDownscaler.downscaled(image, maxDimension: Self.reviewImageMaxDimension))
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
            savedCount += 1
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
            Localized.string("The document camera is not available on this device.")
        case .scannerFailed(let reason):
            Localized.string("Scanning failed: \(reason)")
        }
    }
}
