import Foundation
import Testing
@testable import ReceiptKit

/// Per-field accuracy over every fixture. The numbers are printed so `docs/performance.md`
/// can be refreshed, and floors keep a regression from slipping in unnoticed.
struct AccuracyReport {
    struct Field {
        let name: String
        var correct = 0
        var total = 0
        var misses: [String] = []
        var percent: Double { total == 0 ? 100 : Double(correct) / Double(total) * 100 }
    }

    var fields: [Field] = ["merchant", "date", "total", "currency", "issues"].map { Field(name: $0) }

    init(fixtures: [ReceiptFixture]) {
        for fixture in fixtures {
            let parsed = fixture.parse()
            let expected = fixture.expected
            record("merchant", fixture, parsed.merchant == expected.merchant)
            record("date", fixture, parsed.date.map(Self.iso) == expected.date)
            record("total", fixture, parsed.total == expected.total.flatMap { Decimal(string: $0) })
            record("currency", fixture, parsed.currencyCode == expected.currency)
            record("issues", fixture, Set(parsed.issues.map(\.kind)) == Set(expected.issues))
        }
    }

    func field(_ name: String) -> Field { fields.first { $0.name == name }! }

    var summary: String {
        fields.map { String(format: "%-9@ %3d/%-3d %6.1f%%", $0.name as NSString, $0.correct, $0.total, $0.percent) }
            .joined(separator: "\n")
    }

    private mutating func record(_ name: String, _ fixture: ReceiptFixture, _ isCorrect: Bool) {
        guard let index = fields.firstIndex(where: { $0.name == name }) else { return }
        fields[index].total += 1
        if isCorrect { fields[index].correct += 1 } else { fields[index].misses.append(fixture.testDescription) }
    }

    private static func iso(_ date: CalendarDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }
}

@Suite struct QualityReportTests {
    @Test func everyFieldKeepsItsAccuracyFloor() {
        let report = AccuracyReport(fixtures: ReceiptFixture.all)
        print("Accuracy over \(ReceiptFixture.all.count) fixtures\n\(report.summary)")
        for field in report.fields {
            #expect(field.percent >= 95, "\(field.name) fell to \(field.percent)%: \(field.misses)")
        }
    }

    @Test func parsingStaysCheap() {
        let fixtures = ReceiptFixture.all
        let parsers = Dictionary(uniqueKeysWithValues: fixtures.map { ($0.testDescription, DefaultReceiptParser(locale: Locale(identifier: $0.expected.locale))) })
        let rounds = 20
        let clock = ContinuousClock()
        var worst: Duration = .zero
        let total = clock.measure {
            for _ in 0..<rounds {
                for fixture in fixtures {
                    let ocr = OCRResult(text: fixture.text)
                    let elapsed = clock.measure { _ = parsers[fixture.testDescription]!.parse(ocr) }
                    worst = max(worst, elapsed)
                }
            }
        }
        let average = total / (rounds * fixtures.count)
        print("Parse time: average \(average), worst \(worst) over \(rounds * fixtures.count) runs")
        // OCR takes hundreds of milliseconds; parsing must stay far below that.
        #expect(average < .milliseconds(5))
        #expect(worst < .milliseconds(50))
    }
}
