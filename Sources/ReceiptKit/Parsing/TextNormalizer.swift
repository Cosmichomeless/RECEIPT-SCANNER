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
        var text = joinGroupedDigits(in: line)
        text = collapseWhitespace(text)
        text = joinSpacedThousands(in: text)
        text = fixDigitLookalikes(in: text)
        text = fixKeywordLookalikes(in: text)
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

    // MARK: - Digit grouping

    /// `1 234,56` written with a no-break, narrow or thin space, or Swiss `1'234.56`: the mark
    /// groups thousands, so it goes. Plain spaces are left alone here (see `joinSpacedThousands`).
    private static let groupMark = try! NSRegularExpression(pattern: #"(?<=\d)[\u00A0\u202F\u2009'’](?=\d{3}(?!\d))"#)

    private static func joinGroupedDigits(in text: String) -> String {
        replaceMatches(of: groupMark, in: text) { _ in "" }
    }

    /// `TOTAL 1 234,56` with a plain space between the groups. Only joined after some text on the
    /// line and before a two-digit decimal part, so a quantity before a price (`2 100,00` at the
    /// start of a line) is not merged into one number.
    private static let spacedThousands = try! NSRegularExpression(
        pattern: #"(?<=[^\d\s] )\d{1,3}(?: \d{3})+(?=[.,]\d{2}(?!\d))"#
    )

    private static func joinSpacedThousands(in text: String) -> String {
        replaceMatches(of: spacedThousands, in: text) { $0.replacingOccurrences(of: " ", with: "") }
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

    /// Words the parsers look for. `T0TAL` and `IMP0RTE` are read as the real word when a digit
    /// stands in for a letter; any other token is left alone.
    private static let keywords: Set<String> = [
        "TOTAL", "SUBTOTAL", "IMPORTE", "EFECTIVO", "CAMBIO", "TARJETA", "PROPINA", "DESCUENTO",
        "FECHA", "BETRAG", "SUMME", "GESAMT", "TOTALE", "MONTANT", "AMOUNT", "BALANCE", "CHANGE", "TENDER",
    ]
    private static let wordWithDigits = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])(?=[A-Za-z0-9]*[A-Za-z])(?=[A-Za-z0-9]*[0158])[A-Za-z0-9]{4,10}(?![A-Za-z0-9])"#
    )

    private static func fixKeywordLookalikes(in text: String) -> String {
        replaceMatches(of: wordWithDigits, in: text) { token in
            let upper = token.uppercased()
            // 0 is O, 5 is S, 8 is B, and 1 is either I or L (`TOTA1`, `S1MPLE`): try both.
            let base = String(upper.map { character -> Character in
                switch character {
                case "0": "O"
                case "5": "S"
                case "8": "B"
                default: character
                }
            })
            for variant in [base.replacingOccurrences(of: "1", with: "L"), base.replacingOccurrences(of: "1", with: "I")]
            where keywords.contains(variant) {
                return variant
            }
            return nil
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
