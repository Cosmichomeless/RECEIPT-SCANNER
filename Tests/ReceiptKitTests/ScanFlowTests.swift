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

private actor CallCounter {
    private(set) var calls = 0
    func record() { calls += 1 }
}

private struct SlowCountingOCR: OCRService {
    let counter: CallCounter
    func recognizeText(in image: CGImage) async throws -> OCRResult {
        await counter.record()
        try await Task.sleep(for: .milliseconds(100))
        return OCRResult(text: "HELLO")
    }
}

private func makeImage(width: Int, height: Int) throws -> CGImage {
    try #require(
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
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

    @Test func reviewKeepsASmallImageButOcrReadsTheFullCapture() async throws {
        let seen = CallCounter()
        struct SizeOCR: OCRService {
            let counter: CallCounter
            func recognizeText(in image: CGImage) async throws -> OCRResult {
                await counter.record()
                return OCRResult(text: "\(image.width)x\(image.height)")
            }
        }
        let flow = flow(ocr: SizeOCR(counter: seen))
        await flow.handle(.captured(try makeImage(width: 3000, height: 4000)))
        guard case .review(let parsed, let image) = flow.state else {
            Issue.record("expected review, got \(flow.state)")
            return
        }
        #expect(parsed.rawText == "3000x4000")
        #expect(max(image.width, image.height) == ScanFlow.reviewImageMaxDimension)
        #expect(image.width * 4 == image.height * 3)
        #expect(flow.lastTimings?.imageWidth == 3000)
    }

    @Test func smallCapturesAreKeptAsTheyAre() async throws {
        let flow = flow()
        let capture = try makeImage(width: 800, height: 1000)
        await flow.handle(.captured(capture))
        guard case .review(_, let image) = flow.state else {
            Issue.record("expected review, got \(flow.state)")
            return
        }
        #expect(image === capture)
    }

    @Test func aSecondCaptureWhileProcessingIsIgnored() async throws {
        let counter = CallCounter()
        let flow = flow(ocr: SlowCountingOCR(counter: counter))
        let image = try makeImage()
        async let first: Void = flow.handle(.captured(image))
        try await Task.sleep(for: .milliseconds(20))
        await flow.handle(.captured(image))
        await flow.handle(.cancelled)
        await first
        #expect(await counter.calls == 1)
        guard case .review = flow.state else {
            Issue.record("expected review, got \(flow.state)")
            return
        }
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
        #expect(flow.savedCount == 1)
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
