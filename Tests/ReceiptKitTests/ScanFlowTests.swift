import Foundation
import CoreGraphics
import Testing
@testable import ReceiptKit

private struct EchoOCR: OCRService {
    func recognizeText(in image: CGImage) async throws -> OCRResult { OCRResult(text: "HELLO") }
}

private struct FailingOCR: OCRService {
    struct Boom: Error {}
    func recognizeText(in image: CGImage) async throws -> OCRResult { throw Boom() }
}

private struct TextParser: ReceiptParser {
    func parse(_ ocr: OCRResult) -> ParsedReceipt { ParsedReceipt(rawText: ocr.rawText) }
}

private func makeImage() throws -> CGImage {
    try #require(
        CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.makeImage()
    )
}

@MainActor
@Suite struct ScanFlowTests {
    private func flow(ocr: any OCRService = EchoOCR()) -> ScanFlow {
        ScanFlow(processor: ReceiptProcessor(ocr: ocr, parser: TextParser()))
    }

    @Test func capturedImageReachesReview() async throws {
        let flow = flow()
        flow.startScan()
        await flow.handle(.captured(try makeImage()))
        guard case .review(let parsed, _) = flow.state else {
            Issue.record("expected review, got \(flow.state)")
            return
        }
        #expect(parsed.rawText == "HELLO")
    }

    @Test func cancellationReturnsToIdle() async {
        let flow = flow()
        flow.startScan()
        await flow.handle(.cancelled)
        guard case .idle = flow.state else {
            Issue.record("expected idle, got \(flow.state)")
            return
        }
    }

    @Test func scannerErrorBecomesFailure() async {
        let flow = flow()
        await flow.handle(.failed(.scannerFailed("lens blocked")))
        guard case .failed(let message) = flow.state else {
            Issue.record("expected failed, got \(flow.state)")
            return
        }
        #expect(message.contains("lens blocked"))
    }

    @Test func ocrErrorBecomesFailure() async throws {
        let flow = flow(ocr: FailingOCR())
        await flow.handle(.captured(try makeImage()))
        guard case .failed = flow.state else {
            Issue.record("expected failed, got \(flow.state)")
            return
        }
    }
}

private struct FailingRepository: ReceiptRepository {
    struct Boom: LocalizedError { var errorDescription: String? { "disk full" } }
    func save(_ receipt: Receipt) async throws { throw Boom() }
    func fetchAll() async throws -> [Receipt] { [] }
    func receipt(id: Receipt.ID) async throws -> Receipt? { nil }
    func delete(id: Receipt.ID) async throws {}
}

@MainActor
@Suite struct ScanFlowSavingTests {
    private func reviewDraft() -> ReceiptDraft {
        ReceiptDraft(ParsedReceipt(
            merchant: "CAFE LUNA", total: Decimal(string: "9.50"), currencyCode: "EUR", rawText: "raw"
        ))
    }

    @Test func savingStoresCorrectedReceiptAndReturnsToIdle() async throws {
        let repository = InMemoryReceiptRepository()
        let flow = ScanFlow(processor: ReceiptProcessor(ocr: EchoOCR(), parser: TextParser()), repository: repository)
        var draft = reviewDraft()
        draft.merchant = "Café Luna"
        #expect(await flow.save(draft))
        #expect(try await repository.fetchAll().map(\.merchant) == ["Café Luna"])
        guard case .idle = flow.state else {
            Issue.record("expected idle, got \(flow.state)")
            return
        }
    }

    @Test func incompleteDraftIsNotSaved() async throws {
        let repository = InMemoryReceiptRepository()
        let flow = ScanFlow(processor: ReceiptProcessor(ocr: EchoOCR(), parser: TextParser()), repository: repository)
        var draft = reviewDraft()
        draft.totalText = ""
        #expect(await flow.save(draft) == false)
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test func storageFailureKeepsReviewAndReportsError() async throws {
        let flow = ScanFlow(processor: ReceiptProcessor(ocr: EchoOCR(), parser: TextParser()), repository: FailingRepository())
        await flow.handle(.captured(try makeImage()))
        #expect(await flow.save(reviewDraft()) == false)
        #expect(flow.saveError == "disk full")
        guard case .review = flow.state else {
            Issue.record("expected review, got \(flow.state)")
            return
        }
    }
}
