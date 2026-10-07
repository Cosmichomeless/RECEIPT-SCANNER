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
    private let processor: ReceiptProcessor

    public init(processor: ReceiptProcessor) {
        self.processor = processor
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

    public func reset() {
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
