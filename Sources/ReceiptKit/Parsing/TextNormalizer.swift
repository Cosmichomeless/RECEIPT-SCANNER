import Foundation

/// Cleans OCR output before parsing: line breaks, whitespace, decimal formats and common
/// digit misreads. Pure and deterministic.
public struct TextNormalizer: Sendable {
    public init() {}

    public func normalize(_ ocr: OCRResult) -> NormalizedText {
        normalize(rawText: ocr.rawText)
    }

    public func normalize(rawText: String) -> NormalizedText {
        let unified = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines: [NormalizedLine] = []
        for (index, original) in unified.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let cleaned = Self.cleanLine(String(original))
            guard !cleaned.isEmpty else { continue }
            lines.append(NormalizedLine(index: index, original: String(original), text: cleaned))
        }
        return NormalizedText(rawText: rawText, lines: lines)
    }

    // MARK: - Line cleanup

    static func cleanLine(_ line: String) -> String {
        var text = collapseWhitespace(line)
        text = fixDigitLookalikes(in: text)
        text = joinSplitDecimals(in: text)
        text = canonicalizeAmounts(in: text)
        return text
    }

    /// Tabs, no-break and other Unicode spaces become one space; zero-width characters go.
    private static func collapseWhitespace(_ line: String) -> String {
        var result = ""
        var previousWasSpace = true
        for scalar in line.unicodeScalars {
            if scalar == "\u{200B}" || scalar == "\u{FEFF}" || scalar == "\u{00AD}" { continue }
            if scalar.properties.isWhitespace || scalar.properties.generalCategory == .spaceSeparator {
                if !previousWasSpace { result.unicodeScalars.append(" ") }
                previousWasSpace = true
            } else {
                result.unicodeScalars.append(scalar)
                previousWasSpace = false
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - OCR artifacts

    /// `8O.5O` → `80.50`. Only touches tokens that already look like an amount (digits and
    /// look-alike letters ending in a two-character decimal part) and hold a real digit.
    private static let amountLike = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])[0-9OoIl|SB][0-9OoIl|SB.,]*[.,][0-9OoIl|SB]{2}(?![A-Za-z0-9])"#
    )

    private static func fixDigitLookalikes(in text: String) -> String {
        replaceMatches(of: amountLike, in: text) { token in
            guard token.contains(where: \.isASCIIDigit) else { return nil }
            return String(token.map { character in
                switch character {
                case "O", "o": "0"
                case "I", "l", "|": "1"
                case "S": "5"
                case "B": "8"
                default: character
                }
            })
        }
    }

    // MARK: - Decimal formats

    /// `84 .37` and `3 . 25` → `84.37` / `3.25` (spaces OCR put around the decimal mark).
    private static let splitDecimal = try! NSRegularExpression(pattern: #"(?<=\d) +[.,] ?(?=\d{2}(?![\d]))"#)

    private static func joinSplitDecimals(in text: String) -> String {
        replaceMatches(of: splitDecimal, in: text) { token in token.filter { $0 != " " } }
    }

    /// Rewrites amounts with two decimals to `1234.56`: `1.234,56`, `1,234.56`, `84,37`.
    /// Dates such as `06.10.2026` and ambiguous values such as `1,234` are left alone.
    private static let amount = try! NSRegularExpression(
        pattern: #"(?<![0-9])(?<![0-9][.,])(\d+(?:[.,]\d{3})*)[.,](\d{2})(?![0-9])(?![.,]\d)"#
    )

    private static func canonicalizeAmounts(in text: String) -> String {
        replaceMatches(of: amount, in: text) { token in
            guard let decimalMark = token.lastIndex(where: { $0 == "." || $0 == "," }) else { return nil }
            let whole = token[..<decimalMark].filter(\.isASCIIDigit)
            let fraction = token[token.index(after: decimalMark)...]
            return "\(whole).\(fraction)"
        }
    }

    // MARK: - Helpers

    private static func replaceMatches(
        of regex: NSRegularExpression,
        in text: String,
        transform: (String) -> String?
    ) -> String {
        let nsText = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let replacement = transform(String(result[range])) else { continue }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}

extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
