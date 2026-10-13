import Foundation
import Testing
@testable import ReceiptKit

@Suite struct TaxParserTests {
    private func parse(_ raw: String, total: String? = nil) -> TaxBreakdown? {
        let text = TextNormalizer().normalize(rawText: raw)
        return TaxParser().parse(text, total: total.flatMap { Decimal(string: $0) })
    }

    private func d(_ value: String) -> Decimal { Decimal(string: value)! }

    @Test func rowWithBaseAndQuota() {
        let tax = parse("IVA 10%   BASE 6,36  CUOTA 0,64", total: "7.00")
        #expect(tax == TaxBreakdown(base: d("6.36"), rate: 10, amount: d("0.64")))
    }

    @Test func headerFollowedByRows() {
        let tax = parse("""
        IVA   BASE IMP   CUOTA
        10%     6,36      0,64
        21%    10,00      2,10
        """, total: "19.10")
        #expect(tax?.base == d("16.36"))
        #expect(tax?.amount == d("2.74"))
        #expect(tax?.rate == nil, "two rates have no single rate")
    }

    @Test func separateBaseAndTaxLines() {
        let tax = parse("""
        BASE IMPONIBLE   100,00
        IVA 21%           21,00
        TOTAL            121,00
        """, total: "121.00")
        #expect(tax == TaxBreakdown(base: 100, rate: 21, amount: 21))
    }

    @Test func percentWithDecimalsAndGroupedAmounts() {
        let tax = parse("""
        BASE IMPONIBLE   1.000,00
        IVA 21,00 %        210,00
        """, total: "1210.00")
        #expect(tax == TaxBreakdown(base: 1000, rate: 21, amount: 210))
    }

    @Test func rateIsInferredFromBaseAndTax() {
        let tax = parse("BASE IMPONIBLE 50,00\nTOTAL IVA 5,00", total: "55.00")
        #expect(tax == TaxBreakdown(base: 50, rate: 10, amount: 5))
    }

    @Test func subtotalCountsAsBaseOnlyWhenItAddsUp() {
        #expect(parse("SUBTOTAL 76.92\nTAX 7.45", total: "84.37") == TaxBreakdown(base: d("76.92"), rate: nil, amount: d("7.45")))
        #expect(parse("SUBTOTAL 70.00\nTAX 7.45", total: "84.37")?.base == nil)
    }

    @Test func includedVATIsEstimatedFromTheTotal() {
        let tax = parse("TOTAL 35,80 EUR\nIVA INCLUIDO 10%", total: "35.80")
        #expect(tax == TaxBreakdown(base: d("32.55"), rate: 10, amount: d("3.25"), isEstimated: true))
    }

    @Test func rateWithoutFiguresStaysARate() {
        #expect(parse("IVA 21%") == TaxBreakdown(rate: 21))
    }

    @Test func aStrayAmountIsNotATaxRow() {
        // 7,00 is not 10% of 3,00 nor any known rate of it.
        #expect(parse("IVA BASE 3,00 CUOTA 7,00") == nil)
    }

    @Test func germanAndFrenchWords() {
        #expect(parse("Netto 100,00\nMwSt 19% 19,00", total: "119.00") == TaxBreakdown(base: 100, rate: 19, amount: 19))
        #expect(parse("TOTAL HT 100,00\nTVA 20% 20,00", total: "120.00") == TaxBreakdown(base: 100, rate: 20, amount: 20))
    }

    @Test func noTaxMeansNil() {
        #expect(parse("CAFE LUNA\nTOTAL 5,50") == nil)
    }

    @Test func mismatchIsDetected() {
        let tax = TaxBreakdown(base: 100, rate: 21, amount: 21)
        #expect(tax.isConsistent(withTotal: 121))
        #expect(tax.isConsistent(withTotal: d("121.01")))
        #expect(!tax.isConsistent(withTotal: 125))
        #expect(TaxBreakdown(rate: 21).isConsistent(withTotal: 5), "nothing to compare")
    }
}

@Suite struct TaxIDParserTests {
    private func parse(_ raw: String) -> String? {
        TaxIDParser().parse(TextNormalizer().normalize(rawText: raw))
    }

    @Test func validCompanyNumbers() {
        #expect(parse("MERCADONA, S.A.\nA-46103834") == "A46103834")
        #expect(parse("CIF: B12345674") == "B12345674")
        #expect(parse("N.I.F. B-8765432-3") == "B87654323")
    }

    @Test func individualAndForeignNumbers() {
        #expect(parse("NIF 12345678Z") == "12345678Z")
        #expect(parse("NIE X1234567L") == "X1234567L")
    }

    @Test func wrongCheckCharacterNeedsALabel() {
        #expect(parse("CIF B12345678") == "B12345678")
        #expect(parse("B12345678") == nil)
        #expect(parse("TLF 12345678Z0") == nil)
    }

    @Test func validNumberWinsOverLabelledInvalidOne() {
        #expect(parse("CIF B12345678\nA46103834") == "A46103834")
    }

    @Test func plainTextHasNone() {
        #expect(parse("TOTAL 12,50\nGRACIAS") == nil)
    }
}
