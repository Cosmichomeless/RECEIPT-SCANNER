import Foundation
import Testing
@testable import ReceiptKit

@Suite struct DefaultReceiptParserTests {
    private func parse(_ raw: String, locale: String = "es_ES") -> ParsedReceipt {
        DefaultReceiptParser(locale: Locale(identifier: locale)).parse(OCRResult(text: raw))
    }

    @Test func fullReceipt() {
        let parsed = parse("""
        NORTHLINE HARDWARE
        MARKET STREET 12
        FECHA 06/10/2026 12:41
        HEX KEY SET       18.99
        SUBTOTAL          76.92
        TAX                7.45
        TOTAL EUR         84.37
        """)
        #expect(parsed.merchant == "NORTHLINE HARDWARE")
        #expect(parsed.date == CalendarDate(year: 2026, month: 10, day: 6))
        #expect(parsed.total == Decimal(string: "84.37"))
        #expect(parsed.currencyCode == "EUR")
        #expect(parsed.issues.isEmpty)
    }

    @Test func missingFieldsAreReportedNotInvented() {
        let parsed = parse("hello\nworld")
        #expect(parsed.date == nil)
        #expect(parsed.total == nil)
        #expect(parsed.currencyCode == nil)
        #expect(parsed.issues.contains(.missingDate))
        #expect(parsed.issues.contains(.missingTotal))
        #expect(parsed.issues.contains(.missingCurrency))
    }

    @Test func ambiguousCurrencyBecomesAnIssue() {
        let parsed = parse("CAFE LUNA\nTOTAL $12.50", locale: "es_ES")
        #expect(parsed.currencyCode == nil)
        #expect(parsed.issues.contains(.ambiguousCurrency(candidates: ["USD", "MXN", "CAD", "AUD"])))
    }

    @Test func localeResolvesDollar() {
        #expect(parse("CAFE LUNA\nTOTAL $12.50", locale: "en_US").currencyCode == "USD")
    }

    @Test func emptyOCRProducesAllIssues() {
        let parsed = parse("")
        #expect(parsed.issues.count == 4)
    }
}
