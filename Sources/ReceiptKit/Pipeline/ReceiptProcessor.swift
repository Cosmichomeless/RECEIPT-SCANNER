import CoreGraphics
import Foundation
import os

/// How long each stage of one scan took, for tuning on real devices.
public struct ProcessingTimings: Equatable, Sendable {
    public var imageWidth: Int
    public var imageHeight: Int
    public var ocr: Duration
    public var parsing: Duration

    public var total: Duration { ocr + parsing }

    /// Decoded size of the captured bitmap (4 bytes per pixel), the dominant memory cost of a scan.
    public var imageBytes: Int { imageWidth * imageHeight * 4 }
}

/// Runs image → OCR → parser. It depends only on the protocols, so every stage can be
/// replaced by a stub.
public struct ReceiptProcessor: Sendable {
    private static let logger = Logger(subsystem: "ReceiptKit", category: "processing")

    private let ocr: any OCRService
    private let parser: any ReceiptParser

    public init(ocr: any OCRService, parser: any ReceiptParser) {
        self.ocr = ocr
        self.parser = parser
    }

    public func process(_ image: CGImage) async throws -> ParsedReceipt {
        try await processMeasured(image).receipt
    }

    /// Same as `process`, also reporting per-stage timings. Timings are logged (no receipt
    /// content) under the `ReceiptKit` subsystem so they can be read from Console on a device.
    public func processMeasured(_ image: CGImage) async throws -> (receipt: ParsedReceipt, timings: ProcessingTimings) {
        let clock = ContinuousClock()
        var recognized: OCRResult?
        let ocrTime = try await clock.measure { recognized = try await ocr.recognizeText(in: image) }
        guard let recognized else { throw OCRError.noTextFound }
        var receipt: ParsedReceipt?
        let parseTime = clock.measure { receipt = parser.parse(recognized) }
        guard let receipt else { throw OCRError.noTextFound }

        let timings = ProcessingTimings(
            imageWidth: image.width, imageHeight: image.height, ocr: ocrTime, parsing: parseTime
        )
        Self.logger.info(
            "scan \(timings.imageWidth)x\(timings.imageHeight) ocr=\(String(describing: timings.ocr)) parse=\(String(describing: timings.parsing)) lines=\(recognized.lines.count)"
        )
        return (receipt, timings)
    }
}
