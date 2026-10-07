import Foundation
import Testing
@testable import ReceiptKit

@Suite struct DateParserTests {
    private let oct6 = CalendarDate(year: 2026, month: 10, day: 6)

    private func parse(_ raw: String, order: DateOrder? = .dayFirst) -> DateParseResult {
        DateParser(order: order).parse(TextNormalizer().normalize(rawText: raw))
    }

    @Test(arguments: [
        "06/10/2026", "06-10-2026", "06.10.2026", "2026-10-06", "2026/10/06",
        "06 OCT 2026", "6-oct-26", "06/10/26", "6 de octubre 2026", "Oct. 06, 2026", "October 6, 2026",
    ])
    func supportedFormats(_ text: String) {
        #expect(parse("CAFE LUNA\n\(text) 12:41\nTOTAL 9.50") == .found(oct6))
    }

    @Test func unambiguousWhenOnlyOneReadingIsValid() {
        #expect(parse("13/10/2026") == .found(CalendarDate(year: 2026, month: 10, day: 13)))
        #expect(parse("10/13/2026") == .found(CalendarDate(year: 2026, month: 10, day: 13)))
    }

    @Test func orderResolvesAmbiguousNumericDate() {
        #expect(parse("06/10/2026", order: .dayFirst) == .found(oct6))
        #expect(parse("06/10/2026", order: .monthFirst) == .found(CalendarDate(year: 2026, month: 6, day: 10)))
    }

    @Test func unknownOrderReportsBothReadings() {
        #expect(parse("06/10/2026", order: nil) == .ambiguous([oct6, CalendarDate(year: 2026, month: 6, day: 10)]))
    }

    @Test func sameDayAndMonthIsNotAmbiguous() {
        #expect(parse("06/06/2026", order: nil) == .found(CalendarDate(year: 2026, month: 6, day: 6)))
    }

    @Test func invalidDatesAreNotFound() {
        #expect(parse("31/02/2026") == .notFound)
        #expect(parse("32/10/2026") == .notFound)
        #expect(parse("06/10/1850") == .notFound)
        #expect(parse("NO DATE HERE\nTOTAL 9.50") == .notFound)
    }

    @Test func amountsAndPhonesAreNotDates() {
        #expect(parse("TOTAL 06.10\nTEL 555-123-4567\nAUTH 2026") == .notFound)
    }

    @Test func dateKeywordWinsOverOtherDates() {
        let raw = "VALID UNTIL 01/01/2027\nFECHA: 06/10/2026\nEXP 12/12/2026"
        #expect(parse(raw) == .found(oct6))
    }

    @Test func conflictingDatesAreReportedNotGuessed() {
        #expect(parse("05/10/2026\n06/10/2026") == .ambiguous([
            CalendarDate(year: 2026, month: 10, day: 5), oct6,
        ]))
    }

    @Test func repeatedDateCountsOnce() {
        #expect(parse("06/10/2026 12:41\nDATE 06 OCT 2026") == .found(oct6))
    }

    @Test func localeDefaults() {
        #expect(DateOrder.forLocale(Locale(identifier: "en_US")) == .monthFirst)
        #expect(DateOrder.forLocale(Locale(identifier: "es_ES")) == .dayFirst)
    }
}
