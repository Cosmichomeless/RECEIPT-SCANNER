import Foundation

/// How to read `06/10/2026` when both parts could be a month.
public enum DateOrder: Sendable {
    case dayFirst
    case monthFirst

    /// Day-first everywhere except the regions that write month first.
    public static func forLocale(_ locale: Locale) -> DateOrder {
        switch locale.region?.identifier {
        case "US", "PH", "CA": .monthFirst
        default: .dayFirst
        }
    }
}

public enum DateParseResult: Equatable, Sendable {
    case found(CalendarDate)
    /// More than one plausible date. The user decides; nothing is guessed.
    case ambiguous([CalendarDate])
    case notFound
}

/// Detects the purchase date in normalized text.
///
/// Supported: `06/10/2026`, `06-10-2026`, `06.10.2026`, `06/10/26`, `2026-10-06`,
/// `06 OCT 2026`, `6-oct-26`, `OCT 06, 2026` and Spanish month names.
public struct DateParser: Sendable {
    /// `nil` makes numeric dates with two possible readings (`06/10/2026`) ambiguous.
    public let order: DateOrder?
    public let validYears: ClosedRange<Int>

    public init(
        order: DateOrder? = .dayFirst,
        validYears: ClosedRange<Int> = 2000...(Calendar.current.component(.year, from: Date()) + 1)
    ) {
        self.order = order
        self.validYears = validYears
    }

    public func parse(_ text: NormalizedText) -> DateParseResult {
        var keyworded: [[CalendarDate]] = []
        var others: [[CalendarDate]] = []
        for line in text.lines {
            let readings = Self.matches(in: line.text).compactMap(resolve)
            guard !readings.isEmpty else { continue }
            if Self.hasDateKeyword(line.text) { keyworded.append(contentsOf: readings) }
            else { others.append(contentsOf: readings) }
        }
        // Each entry is the set of readings of ONE written date; order of preference first.
        let pool = keyworded.isEmpty ? others : keyworded
        var unique: [[CalendarDate]] = []
        for readings in pool where !unique.contains(readings) { unique.append(readings) }
        switch unique.count {
        case 0: return .notFound
        case 1:
            let readings = unique[0]
            return readings.count == 1 ? .found(readings[0]) : .ambiguous(readings)
        default:
            return .ambiguous(unique.flatMap { $0 }.removingDuplicates())
        }
    }

    // MARK: - Resolution

    private enum Raw {
        case numeric(first: Int, second: Int, year: Int)
        case yearFirst(year: Int, month: Int, day: Int)
        case named(day: Int, month: Int, year: Int)
    }

    /// The readings of one written date, most likely first. Empty when it is not a real date.
    private func resolve(_ raw: Raw) -> [CalendarDate]? {
        let candidates: [CalendarDate]
        switch raw {
        case .yearFirst(let year, let month, let day), .named(let day, let month, let year):
            candidates = [CalendarDate(year: year, month: month, day: day)]
        case .numeric(let first, let second, let year):
            let dayFirst = CalendarDate(year: year, month: second, day: first)
            let monthFirst = CalendarDate(year: year, month: first, day: second)
            let validDayFirst = isValid(dayFirst)
            let validMonthFirst = isValid(monthFirst)
            switch (validDayFirst, validMonthFirst) {
            case (true, false): candidates = [dayFirst]
            case (false, true): candidates = [monthFirst]
            case (true, true) where first == second: candidates = [dayFirst]
            case (true, true):
                switch order {
                case .dayFirst: candidates = [dayFirst]
                case .monthFirst: candidates = [monthFirst]
                case nil: candidates = [dayFirst, monthFirst]
                }
            case (false, false): candidates = []
            }
        }
        let valid = candidates.filter(isValid)
        return valid.isEmpty ? nil : valid
    }

    private func isValid(_ date: CalendarDate) -> Bool {
        guard validYears.contains(date.year), (1...12).contains(date.month), date.day >= 1 else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let range = calendar.range(
            of: .day, in: .month,
            for: calendar.date(from: DateComponents(year: date.year, month: date.month, day: 1))!
        ) else { return false }
        return range.contains(date.day)
    }

    // MARK: - Matching

    private static func year(_ text: String) -> Int? {
        guard let value = Int(text) else { return nil }
        return text.count == 2 ? 2000 + value : value
    }

    private static let isoPattern = try! NSRegularExpression(
        pattern: #"(?<![0-9])(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?![0-9])"#
    )
    private static let numericPattern = try! NSRegularExpression(
        pattern: #"(?<![0-9])(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})(?![0-9])"#
    )
    private static let dayMonthNamePattern = try! NSRegularExpression(
        pattern: #"(?<![0-9])(\d{1,2})(?:st|nd|rd|th|º)?(?: +de)?[ \-/.]*([A-Za-zñÑ]{3,10})\.?(?: +de)?[ \-/.,]*(\d{4}|\d{2})(?![0-9])"#
    )
    private static let monthNameDayPattern = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z])([A-Za-zñÑ]{3,10})\.? +(\d{1,2})(?:st|nd|rd|th)?,? +(\d{4})(?![0-9])"#
    )

    private static func matches(in line: String) -> [Raw] {
        var found: [(location: Int, raw: Raw)] = []
        let ns = line as NSString
        let whole = NSRange(location: 0, length: ns.length)
        func group(_ match: NSTextCheckingResult, _ index: Int) -> String { ns.substring(with: match.range(at: index)) }

        for match in isoPattern.matches(in: line, range: whole) {
            if let y = Int(group(match, 1)), let m = Int(group(match, 2)), let d = Int(group(match, 3)) {
                found.append((match.range.location, .yearFirst(year: y, month: m, day: d)))
            }
        }
        for match in numericPattern.matches(in: line, range: whole) {
            if let a = Int(group(match, 1)), let b = Int(group(match, 2)), let y = year(group(match, 3)) {
                found.append((match.range.location, .numeric(first: a, second: b, year: y)))
            }
        }
        for match in dayMonthNamePattern.matches(in: line, range: whole) {
            if let d = Int(group(match, 1)), let m = monthNumber(group(match, 2)), let y = year(group(match, 3)) {
                found.append((match.range.location, .named(day: d, month: m, year: y)))
            }
        }
        for match in monthNameDayPattern.matches(in: line, range: whole) {
            if let m = monthNumber(group(match, 1)), let d = Int(group(match, 2)), let y = Int(group(match, 3)) {
                found.append((match.range.location, .named(day: d, month: m, year: y)))
            }
        }
        return found.sorted { $0.location < $1.location }.map(\.raw)
    }

    private static let months: [(names: [String], number: Int)] = [
        (["january", "enero"], 1), (["february", "febrero"], 2), (["march", "marzo"], 3),
        (["april", "abril"], 4), (["may", "mayo"], 5), (["june", "junio"], 6),
        (["july", "julio"], 7), (["august", "agosto"], 8),
        (["september", "septiembre", "setiembre"], 9), (["october", "octubre"], 10),
        (["november", "noviembre"], 11), (["december", "diciembre"], 12),
    ]
    /// Spanish and English abbreviations that are not a prefix of the full name.
    private static let abbreviations = ["ene": 1, "abr": 4, "ago": 8, "dic": 12, "sept": 9, "set": 9]

    /// A month name or abbreviation (`oct`, `Oct.`, `octubre`), or `nil` for any other word.
    private static func monthNumber(_ word: String) -> Int? {
        let lower = word.lowercased()
        if let number = abbreviations[lower] { return number }
        guard lower.count >= 3 else { return nil }
        return months.first { entry in entry.names.contains { $0.hasPrefix(lower) } }?.number
    }

    private static let dateKeywords = ["DATE", "FECHA", "DATA", "DATUM"]

    private static func hasDateKeyword(_ line: String) -> Bool {
        let upper = line.uppercased()
        return dateKeywords.contains { upper.contains($0) }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
