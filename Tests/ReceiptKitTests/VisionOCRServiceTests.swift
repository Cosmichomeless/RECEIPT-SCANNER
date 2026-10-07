import CoreGraphics
import CoreText
import Testing
@testable import ReceiptKit

/// Draws black text on white so Vision has something real to read.
private func renderImage(lines: [String], size: CGSize = CGSize(width: 900, height: 500)) throws -> CGImage {
    let context = try #require(
        CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(origin: .zero, size: size))
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 56, nil)
    var y = size.height - 90
    for text in lines {
        let attributed = CFAttributedStringCreate(
            nil, text as CFString,
            [kCTFontAttributeName: font, kCTForegroundColorFromContextAttributeName: true] as CFDictionary
        )!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.textPosition = CGPoint(x: 50, y: y)
        CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        y -= 100
    }
    return try #require(context.makeImage())
}

@Suite struct VisionOCRServiceTests {
    @Test func recognizesRenderedText() async throws {
        let image = try renderImage(lines: ["NORTHLINE HARDWARE", "TOTAL 84.37"])
        let result = try await VisionOCRService().recognizeText(in: image)
        let text = result.rawText.uppercased()
        #expect(text.contains("NORTHLINE"))
        #expect(text.contains("84.37"))
        // Reading order: merchant above total.
        let merchant = try #require(text.range(of: "NORTHLINE"))
        let total = try #require(text.range(of: "TOTAL"))
        #expect(merchant.lowerBound < total.lowerBound)
    }

    @Test func blankImageReportsNoTextFound() async throws {
        let image = try renderImage(lines: [])
        await #expect(throws: OCRError.noTextFound) {
            try await VisionOCRService().recognizeText(in: image)
        }
    }

    @Test func readingOrderGroupsRowsAndSortsLeftToRight() {
        let right = RecognizedLine(text: "6.49", boundingBox: CGRect(x: 0.7, y: 0.50, width: 0.1, height: 0.05))
        let left = RecognizedLine(text: "WOOD GLUE", boundingBox: CGRect(x: 0.1, y: 0.51, width: 0.3, height: 0.05))
        let top = RecognizedLine(text: "SHOP", boundingBox: CGRect(x: 0.1, y: 0.9, width: 0.2, height: 0.05))
        let ordered = VisionOCRService.readingOrder([right, top, left]).map(\.text)
        #expect(ordered == ["SHOP", "WOOD GLUE", "6.49"])
    }
}
