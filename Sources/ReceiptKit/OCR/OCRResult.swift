import CoreGraphics

/// One recognized line of text.
public struct RecognizedLine: Equatable, Sendable {
    public var text: String
    /// 0...1, as reported by the recognizer.
    public var confidence: Float
    /// Normalized image coordinates, origin at the bottom left.
    public var boundingBox: CGRect

    public init(text: String, confidence: Float = 1, boundingBox: CGRect = .zero) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Everything OCR knows about an image. OCR only recognizes text; it never interprets it.
public struct OCRResult: Equatable, Sendable {
    /// Lines in reading order, top to bottom.
    public var lines: [RecognizedLine]

    public init(lines: [RecognizedLine]) {
        self.lines = lines
    }

    /// Builds a result from plain text, one line per newline. Used by tests and fixtures.
    public init(text: String) {
        self.init(lines: text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { RecognizedLine(text: String($0)) })
    }

    public var rawText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}
