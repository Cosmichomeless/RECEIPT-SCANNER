import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import ReceiptKit

/// A receipt-like page drawn at a given pixel size (text scales with the page, as a photo would).
private func renderReceipt(width: Int, height: Int) throws -> CGImage {
    let context = try #require(
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let lines = [
        "NORTHLINE HARDWARE", "12 Main Street", "Date 06/10/2026",
        "Wood glue 6.49", "Screws 3.20", "Sandpaper 4.10", "Paint roller 12.90",
        "SUBTOTAL 26.69", "TAX 2.67", "TOTAL 29.36", "USD", "Thank you",
    ]
    let fontSize = Double(width) / 16
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    var y = Double(height) - fontSize * 1.6
    for text in lines {
        let attributed = CFAttributedStringCreate(
            nil, text as CFString,
            [kCTFontAttributeName: font, kCTForegroundColorFromContextAttributeName: true] as CFDictionary
        )!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.textPosition = CGPoint(x: fontSize, y: y)
        CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        y -= fontSize * 1.5
    }
    return try #require(context.makeImage())
}

@Suite struct OCRCostMeasurementTests {
    @Test func downscalerKeepsAspectRatioAndLeavesSmallImagesAlone() throws {
        let big = try renderReceipt(width: 3000, height: 4000)
        let small = ImageDownscaler.downscaled(big, maxDimension: 2000)
        #expect(small.width == 1500)
        #expect(small.height == 2000)
        #expect(ImageDownscaler.downscaled(small, maxDimension: 2000) === small)
        #expect(ImageDownscaler.downscaled(big, maxDimension: 0) === big)
    }

    /// Prints OCR time and whether the total is still read, for a native-size capture against
    /// downscaled copies. Run with `swift test --filter OCRCostMeasurementTests` to refresh the table.
    @Test func downscalingKeepsTheTotalReadable() async throws {
        let native = try renderReceipt(width: 3024, height: 4032)
        let clock = ContinuousClock()
        var readable: [Int: Bool] = [:]
        for maxDimension in [0, 3000, 2400, 1800, 1200, 800] {
            let image = ImageDownscaler.downscaled(native, maxDimension: maxDimension)
            _ = try await VisionOCRService(maxPixelDimension: 0).recognizeText(in: image)  // warm up
            var best: Duration = .seconds(60)
            var text = ""
            for _ in 0..<3 {
                var result: OCRResult?
                let elapsed = try await clock.measure { result = try await VisionOCRService(maxPixelDimension: 0).recognizeText(in: image) }
                best = min(best, elapsed)
                text = result?.rawText ?? ""
            }
            let parsed = DefaultReceiptParser(locale: Locale(identifier: "en_US")).parse(OCRResult(text: text))
            readable[maxDimension] = parsed.total == Decimal(string: "29.36")
            print("OCR \(image.width)x\(image.height): \(best), total \(parsed.total.map { "\($0)" } ?? "nil"), merchant \(parsed.merchant ?? "nil")")
        }
        #expect(readable[2400] == true)
    }
}

@Suite struct ProcessingTimingsTests {
    private struct StubOCR: OCRService {
        func recognizeText(in image: CGImage) async throws -> OCRResult { OCRResult(text: "CORNER SHOP\nTOTAL 5.00") }
    }

    @Test func processorReportsImageSizeAndStageTimings() async throws {
        let image = try renderReceipt(width: 300, height: 400)
        let processor = ReceiptProcessor(ocr: StubOCR(), parser: DefaultReceiptParser(locale: Locale(identifier: "en_US")))
        let (receipt, timings) = try await processor.processMeasured(image)
        #expect(receipt.merchant == "CORNER SHOP")
        #expect(timings.imageWidth == 300 && timings.imageHeight == 400)
        #expect(timings.imageBytes == 480_000)
        #expect(timings.total == timings.ocr + timings.parsing)
    }

    @Test @MainActor func scanFlowKeepsTheLastTimings() async throws {
        let image = try renderReceipt(width: 300, height: 400)
        let flow = ScanFlow(processor: ReceiptProcessor(ocr: StubOCR(), parser: DefaultReceiptParser(locale: Locale(identifier: "en_US"))))
        #expect(flow.lastTimings == nil)
        await flow.handle(.captured(image))
        #expect(flow.lastTimings?.imageWidth == 300)
    }
}
