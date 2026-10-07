import CoreGraphics

/// Result of asking the user to capture a receipt.
public enum CaptureOutcome: Sendable {
    case captured(CGImage)
    case cancelled
    case failed(CaptureError)
}

public enum CaptureError: Error, Equatable, Sendable {
    case cameraUnavailable
    case scannerFailed(String)
}

/// Image capture boundary. The VisionKit implementation lives in the app target;
/// tests and previews supply stubs.
public protocol ReceiptImageCapture: Sendable {
    @MainActor func captureReceipt() async -> CaptureOutcome
}
