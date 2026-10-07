import CoreGraphics

/// Runs image → OCR → parser. It depends only on the protocols, so every stage can be
/// replaced by a stub.
public struct ReceiptProcessor: Sendable {
    private let ocr: any OCRService
    private let parser: any ReceiptParser

    public init(ocr: any OCRService, parser: any ReceiptParser) {
        self.ocr = ocr
        self.parser = parser
    }

    public func process(_ image: CGImage) async throws -> ParsedReceipt {
        parser.parse(try await ocr.recognizeText(in: image))
    }
}
