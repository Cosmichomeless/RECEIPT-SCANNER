import CoreGraphics
import Foundation
import ReceiptKit

/// Temporary wiring until the Vision OCR service and the real parser land.
struct PendingOCRService: OCRService {
    struct NotImplemented: Error, LocalizedError {
        var errorDescription: String? { "Text recognition is not available yet." }
    }

    func recognizeText(in image: CGImage) async throws -> OCRResult {
        throw NotImplemented()
    }
}

struct RawTextParser: ReceiptParser {
    func parse(_ ocr: OCRResult) -> ParsedReceipt {
        ParsedReceipt(rawText: ocr.rawText)
    }
}
