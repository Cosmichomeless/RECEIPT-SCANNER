import CoreGraphics
import Vision

/// On-device text recognition with Vision. Nothing leaves the device.
public struct VisionOCRService: OCRService {
    public init() {}

    public func recognizeText(in image: CGImage) async throws -> OCRResult {
        guard image.width > 0, image.height > 0 else { throw OCRError.invalidImage }
        return try await Task.detached(priority: .userInitiated) {
            try Self.recognize(image)
        }.value
    }

    private static func recognize(_ image: CGImage) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Receipts are mostly numbers and abbreviations; dictionary correction rewrites them.
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true

        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch {
            throw OCRError.recognitionFailed(error.localizedDescription)
        }

        let lines = (request.results ?? [])
            .compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return nil }
                return RecognizedLine(
                    text: text,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox
                )
            }
        guard !lines.isEmpty else { throw OCRError.noTextFound }
        return OCRResult(lines: readingOrder(lines))
    }

    /// Top to bottom, then left to right. Boxes whose vertical centers are closer than
    /// half a line height are treated as the same row.
    static func readingOrder(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        let sorted = lines.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[RecognizedLine]] = []
        for line in sorted {
            if let last = rows.last?.first,
               abs(last.boundingBox.midY - line.boundingBox.midY) < last.boundingBox.height / 2 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.flatMap { $0.sorted { $0.boundingBox.minX < $1.boundingBox.minX } }
    }
}
