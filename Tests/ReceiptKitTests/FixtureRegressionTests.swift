import Foundation
import Testing
@testable import ReceiptKit

/// A receipt text with the values a careful reader would extract. See `Fixtures/README.md`.
struct ReceiptFixture: Sendable, CustomTestStringConvertible {
    struct Expected: Decodable, Sendable {
        let locale: String
        let merchant: String?
        let date: String?
        let total: String?
        let currency: String?
        let issues: [String]
        // VAT figures and tax ID are checked only when the file has them. An explicit `null`
        // for `taxRate` means the receipt mixes rates.
        let taxBase: String?
        let taxRate: String?
        let taxAmount: String?
        let taxID: String?
    }

    let category: String
    let name: String
    let text: String
    let expected: Expected

    var testDescription: String { "\(category)/\(name)" }

    static let all: [ReceiptFixture] = {
        guard let root = Bundle.module.resourceURL?.appendingPathComponent("Fixtures") else { return [] }
        return load(from: root)
    }()

    /// Fixtures from a directory: either one folder per category (`supermarket/a.txt` + `a.json`)
    /// or the pairs directly inside it, which get the category `real`.
    static func load(from root: URL) -> [ReceiptFixture] {
        let manager = FileManager.default
        let entries = ((try? manager.contentsOfDirectory(atPath: root.path)) ?? []).sorted()
        var fixtures = pairs(in: root, category: "real")
        for category in entries {
            var isDirectory: ObjCBool = false
            let directory = root.appendingPathComponent(category)
            guard manager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            fixtures += pairs(in: directory, category: category)
        }
        return fixtures
    }

    private static func pairs(in directory: URL, category: String) -> [ReceiptFixture] {
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
        var fixtures: [ReceiptFixture] = []
        for file in files where file.hasSuffix(".txt") {
            let name = String(file.dropLast(4))
            guard
                let text = try? String(contentsOf: directory.appendingPathComponent(file), encoding: .utf8),
                let json = try? Data(contentsOf: directory.appendingPathComponent(name + ".json")),
                let expected = try? JSONDecoder().decode(Expected.self, from: json)
            else { continue }
            fixtures.append(ReceiptFixture(category: category, name: name, text: text, expected: expected))
        }
        return fixtures
    }

    func parse() -> ParsedReceipt {
        DefaultReceiptParser(locale: Locale(identifier: expected.locale)).parse(OCRResult(text: text))
    }
}

extension ParsingIssue {
    /// The case name without its payload, as written in fixture files.
    var kind: String {
        switch self {
        case .missingMerchant: "missingMerchant"
        case .missingDate: "missingDate"
        case .ambiguousDate: "ambiguousDate"
        case .missingTotal: "missingTotal"
        case .missingCurrency: "missingCurrency"
        case .ambiguousCurrency: "ambiguousCurrency"
        case .taxMismatch: "taxMismatch"
        }
    }
}

@Suite struct FixtureRegressionTests {
    @Test func fixturesAreCoveringEveryCategory() {
        let categories = Set(ReceiptFixture.all.map(\.category))
        #expect(categories == ["supermarket", "restaurant", "fuel-station", "hardware-store", "pharmacy", "taxi", "malformed"])
        #expect(ReceiptFixture.all.count >= 20)
    }

    @Test(arguments: ReceiptFixture.all)
    func parsesLikeAReader(_ fixture: ReceiptFixture) {
        let parsed = fixture.parse()
        let expected = fixture.expected
        #expect(parsed.merchant == expected.merchant, "merchant")
        #expect(parsed.date.map(Self.iso) == expected.date, "date")
        #expect(parsed.total == expected.total.flatMap { Decimal(string: $0) }, "total")
        #expect(parsed.currencyCode == expected.currency, "currency")
        #expect(Set(parsed.issues.map(\.kind)) == Set(expected.issues), "issues")
        if expected.taxBase != nil || expected.taxAmount != nil {
            #expect(parsed.tax?.base == expected.taxBase.flatMap { Decimal(string: $0) }, "tax base")
            #expect(parsed.tax?.rate == expected.taxRate.flatMap { Decimal(string: $0) }, "tax rate")
            #expect(parsed.tax?.amount == expected.taxAmount.flatMap { Decimal(string: $0) }, "tax amount")
        }
        if let taxID = expected.taxID {
            #expect(parsed.merchantTaxID == taxID, "tax ID")
        }
    }

    private static func iso(_ date: CalendarDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }
}
