import Foundation
import Testing
@testable import ReceiptKit

@Suite struct CurrencyParserTests {
    private func currency(_ raw: String, locale: String? = nil) -> CurrencyParseResult {
        CurrencyParser(locale: locale.map(Locale.init(identifier:)))
            .parse(TextNormalizer().normalize(rawText: raw))
    }

    @Test(arguments: [
        ("TOTAL 12,50 €", "EUR"), ("TOTAL €12,50", "EUR"), ("TOTAL £8.20", "GBP"),
        ("TOTAL R$ 45,90", "BRL"), ("TOTAL US$ 10.00", "USD"), ("TOTAL 99 zł", "PLN"),
        ("TOTAL ₹ 450.00", "INR"), ("TOTAL 12.50 CHF", "CHF"), ("TOTAL 300.00 MXN", "MXN"),
        ("Total EUR 12.50", "EUR"),
    ])
    func explicitMarks(_ line: String, _ code: String) {
        #expect(currency("SHOP\n\(line)") == .found(code))
    }

    @Test func codeBeatsSymbol() {
        #expect(currency("SHOP\nTOTAL $ 450.00 MXN") == .found("MXN"))
    }

    @Test func bareDollarIsAmbiguousWithoutContext() {
        #expect(currency("SHOP\nTOTAL $12.50") == .ambiguous(["USD", "MXN", "CAD", "AUD"]))
    }

    @Test func localeResolvesSharedSymbol() {
        #expect(currency("SHOP\nTOTAL $12.50", locale: "en_US") == .found("USD"))
        #expect(currency("SHOP\nTOTAL $450.00", locale: "es_MX") == .found("MXN"))
        #expect(currency("SHOP\nTOTAL $12.50", locale: "en_AU") == .found("AUD"))
    }

    @Test func localeOutsideCandidatesDoesNotOverride() {
        // A euro-zone phone scanning a dollar receipt: the locale must not turn it into EUR.
        #expect(currency("SHOP\nTOTAL $12.50", locale: "es_ES") == .ambiguous(["USD", "MXN", "CAD", "AUD"]))
    }

    @Test func decimalCommaNarrowsDollarCurrencies() {
        #expect(currency("SHOP\nTOTAL $ 1250,00") == .ambiguous(["ARS", "CLP", "COP"]))
    }

    @Test func yenIsAmbiguousAcrossJapanAndChina() {
        #expect(currency("SHOP\nTOTAL ¥1200") == .ambiguous(["JPY", "CNY"]))
        #expect(currency("SHOP\nTOTAL ¥1200", locale: "ja_JP") == .found("JPY"))
    }

    @Test func noMarksIsNotFoundEvenWithLocale() {
        #expect(currency("SHOP\nTOTAL 12.50", locale: "en_US") == .notFound)
        #expect(currency("") == .notFound)
    }

    @Test func conflictingCodesAreAmbiguous() {
        #expect(currency("SHOP\nPRICE 10.00 USD\nCHARGED 9.20 EUR") == .ambiguous(["EUR", "USD"]))
    }

    @Test func majorityCodeWins() {
        #expect(currency("SHOP\nA 1.00 EUR\nB 2.00 EUR\nC 3.00 USD") == .found("EUR"))
    }

    @Test func wordsThatLookLikeCodesAreIgnored() {
        #expect(currency("ALL THE BEST\nTRY AGAIN\nTOTAL 12.50") == .notFound)
        #expect(currency("Eur 12.50 usd") == .notFound)
    }

    @Test func strayDollarSignIsIgnored() {
        #expect(currency("CAFE $$$ DELUXE\nTOTAL 12.50") == .notFound)
    }

    @Test func standaloneSymbolCountsWithoutNumber() {
        #expect(currency("SHOP\nTOTAL (€)    7,00") == .found("EUR"))
        #expect(currency("SHOP\nPRICES IN ($)\nTOTAL 7.00") == .notFound)
    }
}
