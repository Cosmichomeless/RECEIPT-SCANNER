import Testing
@testable import ReceiptKit

@Suite struct TextNormalizerTests {
    private let normalizer = TextNormalizer()

    private func lines(_ raw: String) -> [String] {
        normalizer.normalize(rawText: raw).lines.map(\.text)
    }

    @Test func unifiesLineBreaksAndDropsEmptyLines() {
        #expect(lines("A\r\nB\rC\n\n   \nD") == ["A", "B", "C", "D"])
    }

    @Test func collapsesWhitespace() {
        #expect(lines("  HEX\tKEY   SET \u{00A0}  18.99  ") == ["HEX KEY SET 18.99"])
    }

    @Test func removesZeroWidthCharacters() {
        #expect(lines("TO\u{200B}TAL 5.00") == ["TOTAL 5.00"])
    }

    @Test(arguments: [
        ("TOTAL 84,37", "TOTAL 84.37"),
        ("TOTAL 1.234,56", "TOTAL 1234.56"),
        ("TOTAL 1,234.56", "TOTAL 1234.56"),
        ("TOTAL 1 234,56", "TOTAL 1 234.56"),
        ("TOTAL 84.37", "TOTAL 84.37"),
        ("TOTAL 84 .37", "TOTAL 84.37"),
        ("TOTAL € 84,37", "TOTAL € 84.37"),
        ("84,37 EUR", "84.37 EUR"),
    ])
    func normalizesDecimalFormats(input: String, expected: String) {
        #expect(lines(input) == [expected])
    }

    @Test(arguments: [
        "06.10.2026",
        "06,10,2026",
        "06/10/2026",
        "2026-10-06",
        "12:45",
        "VISA ****4471",
        "1,234",
    ])
    func leavesNonAmountsAlone(input: String) {
        #expect(lines(input) == [input])
    }

    @Test(arguments: [
        ("TOTAL 8O.5O", "TOTAL 80.50"),
        ("TOTAL 1O,99", "TOTAL 10.99"),
        ("TOTAL l5.OO", "TOTAL 15.00"),
        ("TOTAL 4S.B0", "TOTAL 45.80"),
    ])
    func fixesDigitLookalikesInsideAmounts(input: String, expected: String) {
        #expect(lines(input) == [expected])
    }

    @Test func doesNotRewriteWordsThatLookLikeAmounts() {
        #expect(lines("SO.OO BOB.IO") == ["SO.OO BOB.IO"])
        #expect(lines("COBOL SOLO") == ["COBOL SOLO"])
    }

    @Test func keepsRawTextAndOriginalLinesTraceable() {
        let raw = "  SHOP  \n\nTOTAL  84,37"
        let result = normalizer.normalize(rawText: raw)
        #expect(result.rawText == raw)
        #expect(result.lines == [
            NormalizedLine(index: 0, original: "  SHOP  ", text: "SHOP"),
            NormalizedLine(index: 2, original: "TOTAL  84,37", text: "TOTAL 84.37"),
        ])
    }

    @Test func normalizesOCRResult() {
        let result = normalizer.normalize(OCRResult(text: "A\nTOTAL 1,00"))
        #expect(result.lines.map(\.text) == ["A", "TOTAL 1.00"])
    }
}
