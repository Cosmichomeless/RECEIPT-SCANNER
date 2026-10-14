import Foundation
import ImageIO
import Testing
@testable import ReceiptKit

/// Per-field accuracy over a set of fixtures. The numbers are printed so `docs/performance.md`
/// can be refreshed, and floors keep a regression from slipping in unnoticed.
///
/// `tax` and `taxID` only count fixtures whose expected file has those values.
struct AccuracyReport {
    struct Field {
        let name: String
        var correct = 0
        var total = 0
        var misses: [String] = []
        var percent: Double { total == 0 ? 100 : Double(correct) / Double(total) * 100 }
    }

    static let fieldNames = ["merchant", "date", "total", "currency", "issues", "tax", "taxID"]

    var fields: [Field] = fieldNames.map { Field(name: $0) }
    let count: Int
    /// Fixtures with at least one wrong field, with what was read against what was expected.
    private(set) var details: [String] = []

    init(fixtures: [ReceiptFixture]) {
        count = fixtures.count
        for fixture in fixtures {
            let parsed = fixture.parse()
            let expected = fixture.expected
            var wrong: [String] = []
            func check(_ name: String, _ isCorrect: Bool, read: @autoclosure () -> String, want: String) {
                record(name, fixture, isCorrect)
                if !isCorrect { wrong.append("\(name): read \(read()), expected \(want)") }
            }
            let expectedTotal = expected.total.flatMap { Decimal(string: $0) }
            check("merchant", parsed.merchant == expected.merchant,
                  read: "\(parsed.merchant ?? "nil")", want: "\(expected.merchant ?? "nil")")
            check("date", parsed.date.map(Self.iso) == expected.date,
                  read: "\(parsed.date.map(Self.iso) ?? "nil")", want: "\(expected.date ?? "nil")")
            check("total", parsed.total == expectedTotal,
                  read: "\(parsed.total.map { "\($0)" } ?? "nil")", want: "\(expected.total ?? "nil")")
            check("currency", parsed.currencyCode == expected.currency,
                  read: "\(parsed.currencyCode ?? "nil")", want: "\(expected.currency ?? "nil")")
            let issues = Set(parsed.issues.map(\.kind)), wanted = Set(expected.issues)
            check("issues", issues == wanted, read: "\(issues.sorted())", want: "\(wanted.sorted())")
            if expected.taxBase != nil || expected.taxAmount != nil {
                let isCorrect = parsed.tax?.base == expected.taxBase.flatMap { Decimal(string: $0) }
                    && parsed.tax?.rate == expected.taxRate.flatMap { Decimal(string: $0) }
                    && parsed.tax?.amount == expected.taxAmount.flatMap { Decimal(string: $0) }
                check("tax", isCorrect,
                      read: "base \(parsed.tax?.base.map { "\($0)" } ?? "nil") rate \(parsed.tax?.rate.map { "\($0)" } ?? "nil") amount \(parsed.tax?.amount.map { "\($0)" } ?? "nil")",
                      want: "base \(expected.taxBase ?? "nil") rate \(expected.taxRate ?? "nil") amount \(expected.taxAmount ?? "nil")")
            }
            if let taxID = expected.taxID {
                check("taxID", parsed.merchantTaxID == taxID, read: "\(parsed.merchantTaxID ?? "nil")", want: taxID)
            }
            if !wrong.isEmpty { details.append("\(fixture.testDescription): " + wrong.joined(separator: "; ")) }
        }
    }

    func field(_ name: String) -> Field { fields.first { $0.name == name }! }

    var summary: String {
        fields.filter { $0.total > 0 }
            .map { String(format: "%-9@ %3d/%-3d %6.1f%%", $0.name as NSString, $0.correct, $0.total, $0.percent) }
            .joined(separator: "\n")
    }

    /// Markdown with the overall table, the breakdown by locale and by category, and every miss.
    static func markdown(for fixtures: [ReceiptFixture], title: String) -> String {
        func table(_ heading: String, _ groups: [(String, [ReceiptFixture])]) -> String {
            let header = "| \(heading) | tickets | " + fieldNames.joined(separator: " | ") + " |\n"
                + "|---|---|" + fieldNames.map { _ in "---" }.joined(separator: "|") + "|\n"
            let rows = groups.map { name, members -> String in
                let report = AccuracyReport(fixtures: members)
                let cells = report.fields.map { $0.total == 0 ? "-" : String(format: "%.1f%% (%d/%d)", $0.percent, $0.correct, $0.total) }
                return "| \(name) | \(members.count) | " + cells.joined(separator: " | ") + " |"
            }
            return header + rows.joined(separator: "\n") + "\n"
        }
        func grouped(_ key: (ReceiptFixture) -> String) -> [(String, [ReceiptFixture])] {
            Dictionary(grouping: fixtures, by: key).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        }
        let overall = AccuracyReport(fixtures: fixtures)
        var text = "# \(title)\n\n\(fixtures.count) tickets.\n\n"
        text += table("all", [("all", fixtures)]) + "\n"
        text += table("locale", grouped { $0.expected.locale }) + "\n"
        text += table("category", grouped(\.category)) + "\n"
        text += overall.details.isEmpty
            ? "No misses.\n"
            : "## Misses\n\n" + overall.details.map { "- \($0)" }.joined(separator: "\n") + "\n"
        return text
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
        for field in report.fields where field.total > 0 {
            #expect(field.percent >= 95, "\(field.name) fell to \(field.percent)%: \(field.misses)")
        }
    }

    /// Measures tickets that are not in the repository. Point `RECEIPT_FIXTURES_DIR` at a folder of
    /// `name.txt` (the OCR text) + `name.json` (what a reader sees, same schema as `Fixtures/`) pairs,
    /// and optionally `RECEIPT_REPORT_FILE` at a Markdown file to write. See `scripts/measure-accuracy.sh`.
    /// There are no floors here: real tickets are for finding what to improve.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RECEIPT_FIXTURES_DIR"] != nil))
    func measuresExternalTickets() throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = try #require(environment["RECEIPT_FIXTURES_DIR"])
        let fixtures = ReceiptFixture.load(from: URL(fileURLWithPath: (directory as NSString).expandingTildeInPath))
        #expect(!fixtures.isEmpty, "no name.txt + name.json pairs found in \(directory)")
        let report = AccuracyReport.markdown(for: fixtures, title: "Accuracy over \(directory)")
        print(report)
        if let path = environment["RECEIPT_REPORT_FILE"] {
            try report.write(toFile: (path as NSString).expandingTildeInPath, atomically: true, encoding: .utf8)
        }
    }

    /// Turns photos of tickets into the pairs `measuresExternalTickets` reads: runs the app's own OCR over
    /// every image in `RECEIPT_IMAGES_DIR` and writes `name.txt` and a draft `name.json` to
    /// `RECEIPT_FIXTURES_DIR`. The draft holds what the parser read; the user must correct it against
    /// the paper ticket, or the measurement only confirms the parser agrees with itself.
    /// See `scripts/ocr-tickets.sh`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RECEIPT_IMAGES_DIR"] != nil))
    func draftsExpectedFilesFromTicketPhotos() async throws {
        let environment = ProcessInfo.processInfo.environment
        let images = URL(fileURLWithPath: (try #require(environment["RECEIPT_IMAGES_DIR"]) as NSString).expandingTildeInPath)
        let output = URL(fileURLWithPath: (try #require(environment["RECEIPT_FIXTURES_DIR"]) as NSString).expandingTildeInPath)
        let locale = Locale(identifier: environment["RECEIPT_LOCALE"] ?? "es_ES")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tiff"]
        let files = try FileManager.default.contentsOfDirectory(atPath: images.path).sorted()
            .filter { extensions.contains(($0 as NSString).pathExtension.lowercased()) }
        #expect(!files.isEmpty, "no images in \(images.path)")
        for file in files {
            let name = (file as NSString).deletingPathExtension
            guard let source = CGImageSourceCreateWithURL(images.appendingPathComponent(file) as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                print("Skipped \(file): not readable as an image")
                continue
            }
            do {
                let ocr = try await VisionOCRService().recognizeText(in: image)
                let parsed = DefaultReceiptParser(locale: locale).parse(ocr)
                try ocr.rawText.write(to: output.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
                let draft = Self.draftJSON(parsed, locale: locale)
                try draft.write(to: output.appendingPathComponent(name + ".json"), atomically: true, encoding: .utf8)
                print("Wrote \(name).txt and \(name).json (check the JSON against the paper ticket)")
            } catch {
                print("Skipped \(file): \(error)")
            }
        }
    }

    private static func draftJSON(_ parsed: ParsedReceipt, locale: Locale) -> String {
        func value(_ text: String?) -> String { text.map { "\"\($0)\"" } ?? "null" }
        let date = parsed.date.map { String(format: "%04d-%02d-%02d", $0.year, $0.month, $0.day) }
        let issues = parsed.issues.map { "\"\($0.kind)\"" }.joined(separator: ", ")
        return """
        {
          "locale": "\(locale.identifier)",
          "merchant": \(value(parsed.merchant)),
          "date": \(value(date)),
          "total": \(value(parsed.total.map { String(format: "%.2f", NSDecimalNumber(decimal: $0).doubleValue) })),
          "currency": \(value(parsed.currencyCode)),
          "issues": [\(issues)]
        }

        """
    }

    @Test func markdownReportListsMisses() {
        let fixtures = ReceiptFixture.all
        let report = AccuracyReport.markdown(for: fixtures, title: "Test")
        #expect(report.contains("| locale |"))
        #expect(report.contains("| category |"))
        #expect(report.contains("| es_ES |"))
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
        // The slowest single run is one sample out of 1780, so a shared CI runner (a busy virtual machine running
        // other tests in parallel) gets more room. The average above is the same everywhere.
        let worstBudget: Duration = ProcessInfo.processInfo.environment["CI"] != nil ? .milliseconds(250) : .milliseconds(50)
        #expect(worst < worstBudget)
    }
}
