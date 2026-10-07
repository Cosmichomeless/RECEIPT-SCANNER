# Architecture

The pipeline is split into four boundaries. Each one is a protocol in the
`ReceiptKit` Swift package (`Sources/ReceiptKit`), so any stage can be replaced by a
stub.

```text
ReceiptImageCapture ─▶ CGImage ─▶ OCRService ─▶ OCRResult ─▶ ReceiptParser ─▶ ParsedReceipt
                                                                                    │
                                                                    user review ◀───┘
                                                                         │
                                                                         ▼
                                                                      Receipt ─▶ ReceiptRepository
```

| Boundary | Interface | Responsibility |
|----------|-----------|----------------|
| Image capture | `ReceiptImageCapture.captureReceipt() -> CaptureOutcome` | Produce a `CGImage`, or report cancellation / failure. VisionKit implementation lives in the app target. |
| OCR | `OCRService.recognizeText(in:) -> OCRResult` | Recognize text only. Never interprets it. |
| Parsing | `ReceiptParser.parse(_:) -> ParsedReceipt` | Pure function from OCR output to structured fields. No I/O. |
| Persistence | `ReceiptRepository` (`save`, `fetchAll`, `receipt(id:)`, `delete`) | Stores validated `Receipt` values. |

`ReceiptProcessor` composes OCR and parsing and depends only on the two protocols.

## Value types

- **`OCRResult`**: ordered `RecognizedLine`s (text, confidence, bounding box) and `rawText`.
  `OCRResult(text:)` builds one from plain text.
- **`ParsedReceipt`**: merchant, date (`CalendarDate`), total (`Decimal`), `currencyCode`,
  `rawText` and `issues`. Unknown fields are `nil`; uncertainty is reported through
  `ParsingIssue`, never guessed.
- **`Receipt`**: the saved, user-validated record: `id`, `merchant`, `date`, `total`,
  `currencyCode`, `rawText`, `createdAt`, `imagePath?`.

## Testability

The parser takes an `OCRResult` and returns a value. Tests build input with
`OCRResult(text:)`, so parsing is exercised without a camera, Vision, or a device
(`swift test` runs on macOS). `ReceiptProcessor` is tested with stub OCR and parser.

## Layout

```text
Package.swift
Sources/ReceiptKit/
├── Capture/       ReceiptImageCapture
├── OCR/           OCRService, OCRResult
├── Parsing/       ReceiptParser (+ field parsers in later work)
├── Pipeline/      ReceiptProcessor
├── Persistence/   ReceiptRepository
└── Models/        Receipt, ParsedReceipt, CalendarDate
Tests/ReceiptKitTests/
```

UI (SwiftUI), the VisionKit scanner and the SwiftData-backed repository are added on
top of this package without changing its boundaries.
