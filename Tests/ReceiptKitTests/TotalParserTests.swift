import Foundation
import Testing
@testable import ReceiptKit

@Suite struct TotalParserTests {
    private let parser = TotalParser()

    private func total(_ raw: String) -> Decimal? {
        parser.parse(TextNormalizer().normalize(rawText: raw))
    }

    private func candidates(_ raw: String) -> [TotalCandidate] {
        parser.candidates(in: TextNormalizer().normalize(rawText: raw))
    }

    @Test func readmeExample() {
        let raw = """
        NORTHLINE HARDWARE
        MARKET STREET

        HEX KEY SET       18.99
        WOOD GLUE          6.49

        SUBTOTAL          76.92
        TAX                7.45
        TOTAL             84.37

        VISA ****4471
        """
        #expect(total(raw) == Decimal(string: "84.37"))
    }

    @Test func subtotalTaxDiscountAndChangeAreNotTotals() {
        let raw = """
        SHOP
        ITEM A 10.00
        ITEM B 20.00
        SUBTOTAL 30.00
        DISCOUNT 3.00
        TAX 2.70
        TOTAL 29.70
        CASH 50.00
        CHANGE 20.30
        """
        #expect(total(raw) == Decimal(string: "29.70"))
        let lines = candidates(raw).filter { $0.score >= TotalParser.acceptanceThreshold }.map(\.lineText)
        #expect(lines == ["TOTAL 29.70"])
    }

    @Test func totalTaxLineIsStillTax() {
        #expect(total("TOTAL TAX 7.45\nTOTAL 84.37") == Decimal(string: "84.37"))
    }

    @Test func strongKeywordsBeatWeakOnes() {
        let raw = "TOTAL 20.00\nPOINTS\nAMOUNT DUE 55.00\nTHANK YOU"
        #expect(total(raw) == Decimal(string: "55.00"))
    }

    @Test func multipleTotalsPreferTheOneThatMatchesSubtotalPlusTax() {
        let raw = """
        SHOP
        SUBTOTAL 100.00
        TAX 21.00
        TOTAL 100.00
        TOTAL 121.00
        """
        #expect(total(raw) == Decimal(string: "121.00"))
    }

    @Test func totalSmallerThanSubtotalIsPenalized() {
        let raw = """
        SUBTOTAL 80.00
        TOTAL 8.00
        TOTAL 88.00
        """
        #expect(total(raw) == Decimal(string: "88.00"))
    }

    @Test func laterTotalWinsATie() {
        #expect(total("TOTAL 10.00\nTOTAL 10.00") == Decimal(string: "10.00"))
        let ranked = candidates("TOTAL 10.00\nTOTAL 12.00")
        #expect(ranked.first?.amount == Decimal(string: "12.00"))
    }

    @Test func amountOnTheLineAfterTheKeyword() {
        #expect(total("ITEM 5.00\nTOTAL\n84.37") == Decimal(string: "84.37"))
    }

    @Test func lastAmountOnTheLineWins() {
        #expect(total("TOTAL 3 ITEMS 84.37") == Decimal(string: "84.37"))
    }

    @Test(arguments: [
        ("TOTAL EUR 84,37", "84.37"),
        ("TOTAL € 1.234,56", "1234.56"),
        ("GRAND TOTAL $1,234.56", "1234.56"),
        ("TOTAL A PAGAR 15,90", "15.90"),
        ("IMPORTE TOTAL 15,90 €", "15.90"),
        ("TOTAL 8O.5O", "80.50"),
    ])
    func formatsAndLanguages(line: String, expected: String) {
        #expect(total("SHOP\n\(line)\nGRACIAS") == Decimal(string: expected))
    }

    @Test func noKeywordMeansNoTotal() {
        #expect(total("SHOP\nITEM 5.00\nITEM 7.50") == nil)
        #expect(total("") == nil)
        #expect(total("NO NUMBERS HERE") == nil)
    }

    @Test func datesAndCardNumbersAreNotAmounts() {
        #expect(total("TOTAL\n06.10.2026\nVISA ****4471") == nil)
    }
}
