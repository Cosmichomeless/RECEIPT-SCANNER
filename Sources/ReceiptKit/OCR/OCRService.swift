import CoreGraphics

public protocol OCRService: Sendable {
    func recognizeText(in image: CGImage) async throws -> OCRResult
}
