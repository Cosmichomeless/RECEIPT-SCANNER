/// Turns OCR output into structured data. Implementations are pure: no camera, no
/// Vision, no I/O, so they can be tested with plain text.
public protocol ReceiptParser: Sendable {
    func parse(_ ocr: OCRResult) -> ParsedReceipt
}
