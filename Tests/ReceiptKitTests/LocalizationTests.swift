import Foundation
import Testing
@testable import ReceiptKit

@Suite struct LocalizationTests {
    private let spanish = Locale(identifier: "es_ES")
    private let french = Locale(identifier: "fr_FR")
    private let german = Locale(identifier: "de_DE")
    private let english = Locale(identifier: "en_US")

    @Test func labelsFollowTheLocale() {
        #expect(Localized.string("VAT", locale: english) == "VAT")
        #expect(Localized.string("VAT", locale: spanish) == "IVA")
        #expect(Localized.string("VAT", locale: french) == "TVA")
        #expect(Localized.string("VAT", locale: german) == "MwSt.")
    }

    @Test func interpolationsKeepTheirPlace() {
        #expect(Localized.string("Total \("EUR")", locale: spanish) == "Total EUR")
        #expect(Localized.string("Total \("EUR")", locale: german) == "Gesamt EUR")
        #expect(Localized.string("From \("1 Oct")", locale: french) == "À partir du 1 Oct")
    }

    @Test func countsUseThePluralRulesOfTheLanguage() {
        #expect(Localized.string("\(1) receipts", locale: english) == "1 receipt")
        #expect(Localized.string("\(3) receipts", locale: english) == "3 receipts")
        #expect(Localized.string("\(1) receipts", locale: spanish) == "1 ticket")
        #expect(Localized.string("\(3) receipts", locale: german) == "3 Belege")
    }

    @Test func unsupportedLanguagesFallBackToEnglish() {
        #expect(Localized.string("VAT", locale: Locale(identifier: "ja_JP")) == "VAT")
    }

    @Test(arguments: [
        "Sources/ReceiptKit/Resources/Localizable.xcstrings",
        "ReceiptScanner/Resources/Localizable.xcstrings",
        "ReceiptScanner/Resources/InfoPlist.xcstrings",
    ])
    func everyKeyIsTranslatedIntoEveryLanguage(catalog: String) throws {
        // A missing language would silently show English in an otherwise translated app.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent(catalog))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: [String: Any]])
        #expect(!strings.isEmpty)
        for (key, entry) in strings where entry["shouldTranslate"] as? Bool != false {
            let languages = Set((entry["localizations"] as? [String: Any])?.keys.map { $0 } ?? [])
            #expect(languages.isSuperset(of: ["es", "fr", "de"]), "\(key) is missing a language: \(languages.sorted())")
        }
    }
}
