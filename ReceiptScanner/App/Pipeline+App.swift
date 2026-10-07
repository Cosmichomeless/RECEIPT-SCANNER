import ReceiptKit

/// Temporary wiring until the real parser lands.
struct RawTextParser: ReceiptParser {
    func parse(_ ocr: OCRResult) -> ParsedReceipt {
        ParsedReceipt(rawText: ocr.rawText)
    }
}
