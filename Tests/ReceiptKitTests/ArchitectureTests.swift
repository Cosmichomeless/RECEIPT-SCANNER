import Foundation
import CoreGraphics
import Testing
@testable import ReceiptKit

private struct StubOCR: OCRService {
    let text: String
    func recognizeText(in image: CGImage) async throws -> OCRResult { OCRResult(text: text) }
}

private struct StubParser: ReceiptParser {
    func parse(_ ocr: OCRResult) -> ParsedReceipt {
        ParsedReceipt(merchant: ocr.lines.first?.text, rawText: ocr.rawText)
    }
}

@Suite struct ArchitectureTests {
    @Test func parserRunsWithoutCameraOrOCR() {
        let parsed = StubParser().parse(OCRResult(text: "NORTHLINE HARDWARE\nTOTAL 84.37"))
        #expect(parsed.merchant == "NORTHLINE HARDWARE")
        #expect(parsed.rawText == "NORTHLINE HARDWARE\nTOTAL 84.37")
    }

    @Test func processorComposesOCRAndParser() async throws {
        let image = try #require(
            CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        )
        let processor = ReceiptProcessor(ocr: StubOCR(text: "CORNER SHOP\nTOTAL 5.00"), parser: StubParser())
        let parsed = try await processor.process(image)
        #expect(parsed.merchant == "CORNER SHOP")
    }

    @Test func ocrResultRawTextJoinsLines() {
        #expect(OCRResult(text: "A\nB").rawText == "A\nB")
    }

    @Test func calendarDateRoundTrips() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let day = CalendarDate(year: 2026, month: 10, day: 6)
        let date = try #require(day.date(in: calendar))
        #expect(CalendarDate(date, in: calendar) == day)
    }
}
