import CoreGraphics
import Foundation
import Testing
@testable import ReceiptKit

@Suite struct ReceiptDraftTests {
    private func draft(
        merchant: String? = "CAFE LUNA", date: CalendarDate? = CalendarDate(year: 2026, month: 10, day: 6),
        total: String? = "9.50", currency: String? = "EUR", issues: [ParsingIssue] = []
    ) -> ReceiptDraft {
        ReceiptDraft(ParsedReceipt(
            merchant: merchant, date: date, total: total.flatMap { Decimal(string: $0) },
            currencyCode: currency, rawText: "raw", issues: issues
        ))
    }

    @Test func completeDraftMakesReceipt() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let receipt = try #require(draft().makeReceipt(calendar: calendar))
        #expect(receipt.merchant == "CAFE LUNA")
        #expect(receipt.total == Decimal(string: "9.5"))
        #expect(receipt.currencyCode == "EUR")
        #expect(receipt.date.map { CalendarDate($0, in: calendar) } == CalendarDate(year: 2026, month: 10, day: 6))
    }

    @Test func missingFieldsBlockSaving() {
        let empty = draft(merchant: nil, total: nil, currency: nil)
        #expect(Set(empty.problems) == [.missingMerchant, .missingTotal, .missingCurrency])
        #expect(empty.makeReceipt() == nil)
    }

    @Test func userFillsMissingFields() {
        var empty = draft(merchant: nil, date: nil, total: nil, currency: nil)
        empty.merchant = "  Corner Shop "
        empty.totalText = "12,50"
        empty.currencyCode = "eur"
        let receipt = empty.makeReceipt()
        #expect(receipt?.merchant == "Corner Shop")
        #expect(receipt?.total == Decimal(string: "12.5"))
        #expect(receipt?.currencyCode == "EUR")
        #expect(receipt?.date == nil)
    }

    @Test(arguments: ["abc", "0", "-5", "1.2.3", "12 EUR"])
    func invalidTotalsAreRejected(_ text: String) {
        var value = draft()
        value.totalText = text
        #expect(value.problems == [.invalidTotal])
    }

    @Test(arguments: [("84.37", "84.37"), ("84,37", "84.37"), ("1,234.56", "1234.56"), ("1.234,56", "1234.56")])
    func amountSeparators(_ text: String, _ expected: String) {
        #expect(ReceiptDraft.parseAmount(text) == Decimal(string: expected))
    }

    @Test func invalidCurrencyIsRejected() {
        var value = draft()
        value.currencyCode = "EURO"
        #expect(value.problems == [.invalidCurrency])
    }

    @Test func suggestionsComeFromAmbiguityIssues() {
        let value = draft(
            date: nil, currency: nil,
            issues: [
                .ambiguousDate(candidates: [CalendarDate(year: 2026, month: 10, day: 6), CalendarDate(year: 2026, month: 6, day: 10)]),
                .ambiguousCurrency(candidates: ["JPY", "CNY"]),
            ]
        )
        #expect(value.dateSuggestions.count == 2)
        #expect(value.currencySuggestions == ["JPY", "CNY"])
    }
}
