/// One line after normalization, linked back to the OCR line it came from.
public struct NormalizedLine: Equatable, Sendable {
    /// Zero-based index of the line in the raw text.
    public let index: Int
    /// The line exactly as OCR produced it.
    public let original: String
    /// Cleaned text, safe for the parsers. Never empty.
    public let text: String

    public init(index: Int, original: String, text: String) {
        self.index = index
        self.original = original
        self.text = text
    }
}

/// Normalized view of an OCR result. `rawText` is never altered, so every parsed value
/// can be traced to the text it came from.
public struct NormalizedText: Equatable, Sendable {
    public let rawText: String
    /// Non-empty lines in reading order.
    public let lines: [NormalizedLine]

    public init(rawText: String, lines: [NormalizedLine]) {
        self.rawText = rawText
        self.lines = lines
    }
}
