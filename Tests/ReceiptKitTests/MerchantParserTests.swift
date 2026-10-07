import Foundation
import Testing
@testable import ReceiptKit

@Suite struct MerchantParserTests {
    private let parser = MerchantParser()

    private func merchant(_ raw: String) -> String? {
        parser.parse(TextNormalizer().normalize(rawText: raw))
    }

    @Test func readmeExample() {
        let raw = """
        NORTHLINE HARDWARE
        MARKET STREET
        HEX KEY SET       18.99
        TOTAL             84.37
        """
        #expect(merchant(raw) == "NORTHLINE HARDWARE")
    }

    @Test func skipsDecorationAndKeepsName() {
        #expect(merchant("*** CAFE LUNA ***\n06/10/2026\nTOTAL 9.50") == "CAFE LUNA")
    }

    @Test(arguments: [
        "123 Main Street",
        "CALLE MAYOR 14",
        "Av. de la Constitución 22",
        "Tel: 555-123-4567",
        "(555) 123-4567",
        "www.example.com",
        "orders@shop.example",
        "RFC: XAXX010101000",
        "VAT ID GB123456789",
        "28013 Madrid",
        "SW1A 1AA",
        "06/10/2026 12:41",
        "1234567890",
        "TOTAL 84.37",
        "RECEIPT",
        "THANK YOU",
    ])
    func rejectsNonMerchantLines(_ line: String) {
        #expect(merchant("\(line)\nCORNER BAKERY\nTOTAL 3.00") == "CORNER BAKERY")
    }

    @Test func linesBelowHeaderAreIgnored() {
        let raw = (1...9).map { _ in "12345" }.joined(separator: "\n") + "\nLATE NAME"
        #expect(merchant(raw) == nil)
    }

    @Test func missingMerchantIsNil() {
        #expect(merchant("06/10/2026\n12.50\nTOTAL 12.50") == nil)
        #expect(merchant("") == nil)
    }

    @Test func prefersEarlierLineWhenSimilar() {
        #expect(merchant("GREEN GROCER\nFRESH PRODUCE\nTOTAL 9.00") == "GREEN GROCER")
    }

    @Test func keepsMixedCaseNames() {
        #expect(merchant("Café de la Plaza\nMesa 4\nTOTAL 21.00") == "Café de la Plaza")
    }

    @Test func nameWithAmpersandAndDigitsIsKept() {
        #expect(merchant("7-ELEVEN\nTOTAL 3.20") == "7-ELEVEN")
    }

    @Test func keepsAbbreviationPeriods() {
        #expect(merchant("MERCADONA, S.A.\nTOTAL 7,00") == "MERCADONA, S.A.")
    }

    @Test func stationNumberIsNotAPostalCode() {
        #expect(merchant("REPSOL ESTACION 12345\nTOTAL 7,00") == "REPSOL ESTACION 12345")
        #expect(merchant("Springfield, IL 62704\nCORNER BAKERY") == "CORNER BAKERY")
    }
}
