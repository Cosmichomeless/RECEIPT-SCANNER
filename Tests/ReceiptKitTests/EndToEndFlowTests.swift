import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import ReceiptKit

/// The demo path with nothing stubbed except the camera: image → Vision OCR → parser → review
/// corrections → SwiftData → history, including a relaunch.
@Suite @MainActor struct EndToEndFlowTests {
    private func render(lines: [String]) throws -> CGImage {
        let size = CGSize(width: 1100, height: 1000)
        let context = try #require(
            CGContext(
                data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 60, nil)
        var y = size.height - 100
        for text in lines {
            let attributed = CFAttributedStringCreate(
                nil, text as CFString,
                [kCTFontAttributeName: font, kCTForegroundColorFromContextAttributeName: true] as CFDictionary
            )!
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.textPosition = CGPoint(x: 60, y: y)
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
            y -= 110
        }
        return try #require(context.makeImage())
    }

    private func makeFlow(repository: any ReceiptRepository) -> ScanFlow {
        ScanFlow(
            processor: ReceiptProcessor(
                ocr: VisionOCRService(), parser: DefaultReceiptParser(locale: Locale(identifier: "en_US"))
            ),
            repository: repository
        )
    }

    @Test func scanCorrectSaveAndFindItInHistoryAfterRelaunch() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("e2e-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let image = try render(lines: ["NORTHLINE HARDWARE", "Date 2026-10-06", "Wood glue 6.49", "Hex key set 18.99", "TOTAL 84.37"])

        // 1. Scan: the sample has no currency, so the parser must ask instead of guessing.
        let repository = SwiftDataReceiptRepository(modelContainer: try ReceiptSchema.makeContainer(url: url))
        let flow = makeFlow(repository: repository)
        flow.startScan()
        await flow.handle(.captured(image))
        guard case .review(let parsed, _) = flow.state else {
            Issue.record("expected review, got \(flow.state)")
            return
        }
        #expect(parsed.merchant?.uppercased() == "NORTHLINE HARDWARE")
        #expect(parsed.total == Decimal(string: "84.37"))
        #expect(parsed.currencyCode == nil)
        #expect(parsed.issues.contains(.missingCurrency))
        #expect(flow.lastTimings != nil)

        // 2. Correction: the user fixes the merchant case and supplies the currency.
        var draft = ReceiptDraft(parsed)
        #expect(draft.canSave == false)
        draft.merchant = "Northline Hardware"
        draft.currencyCode = "EUR"
        #expect(draft.canSave)

        // 3. Save and see it in history.
        let history = HistoryStore(repository: repository)
        #expect(await flow.save(draft))
        await history.reload()
        #expect(history.receipts.map(\.merchant) == ["Northline Hardware"])
        #expect(history.receipts.first?.total == Decimal(string: "84.37"))
        #expect(history.receipts.first?.currencyCode == "EUR")

        // 4. Relaunch: a fresh container on the same file still has it.
        let relaunched = HistoryStore(
            repository: SwiftDataReceiptRepository(modelContainer: try ReceiptSchema.makeContainer(url: url))
        )
        await relaunched.reload()
        #expect(relaunched.receipts == history.receipts)

        // 5. Delete from history.
        let id = try #require(relaunched.receipts.first?.id)
        await relaunched.delete(id)
        #expect(relaunched.receipts.isEmpty)
    }

    @Test func discardingAReviewStoresNothing() async throws {
        let repository = InMemoryReceiptRepository()
        let flow = makeFlow(repository: repository)
        await flow.handle(.captured(try render(lines: ["CORNER SHOP", "TOTAL 5.00"])))
        flow.reset()
        #expect(try await repository.fetchAll().isEmpty)
    }
}
