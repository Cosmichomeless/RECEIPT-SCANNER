import Foundation

public enum CurrencyParseResult: Equatable, Sendable {
    case found(String)
    /// The marks on the receipt fit several currencies (a bare `$`, `¥`, `kr`). Never guessed.
    case ambiguous([String])
    /// No symbol or code at all. The locale is not used on its own: a receipt with no marks
    /// says nothing about its currency, so the user is asked instead.
    case notFound
}

/// Infers the ISO 4217 currency of a receipt.
///
/// Evidence, strongest first:
/// 1. ISO codes printed on the receipt (`EUR`, `MXN`).
/// 2. Symbols tied to one currency (`€`, `£`, `R$`, `zł`, `US$`).
/// 3. Symbols shared by several currencies (`$`, `¥`, `kr`), narrowed by the device locale and
///    then by the decimal separator of the printed amounts.
public struct CurrencyParser: Sendable {
    public let locale: Locale?

    public init(locale: Locale? = nil) {
        self.locale = locale
    }

    public func parse(_ text: NormalizedText) -> CurrencyParseResult {
        let codes = Self.codes(in: text)
        if !codes.isEmpty { return Self.decide(codes) }

        let (specific, shared) = Self.symbols(in: text)
        if !specific.isEmpty { return Self.decide(specific) }
        guard let options = Self.mostCommon(shared) else { return .notFound }

        var narrowed = options
        if let local = locale?.currency?.identifier, narrowed.contains(local) { return .found(local) }
        if let format = Self.decimalSeparator(in: text) {
            let matching = narrowed.filter { Self.commaDecimalCurrencies.contains($0) == (format == ",") }
            if !matching.isEmpty { narrowed = matching }
        }
        return narrowed.count == 1 ? .found(narrowed[0]) : .ambiguous(narrowed)
    }

    // MARK: - Decision

    /// One currency wins only when it has strictly more evidence than every other.
    private static func decide(_ votes: [String: Int]) -> CurrencyParseResult {
        let ranked = votes.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
        guard let top = ranked.first else { return .notFound }
        let leaders = ranked.filter { $0.value == top.value }.map(\.key).sorted()
        return leaders.count == 1 ? .found(top.key) : .ambiguous(leaders)
    }

    private static func mostCommon(_ shared: [[String]: Int]) -> [String]? {
        shared.max { ($0.value, $1.key.joined()) < ($1.value, $0.key.joined()) }?.key
    }

    // MARK: - ISO codes

    private static let isoCodes: Set<String> = [
        "USD", "EUR", "GBP", "MXN", "CAD", "AUD", "NZD", "JPY", "CNY", "CHF", "INR", "BRL", "ARS", "CLP", "COP",
        "UYU", "BOB", "PYG", "GTQ", "CRC", "DOP", "VES", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "RON", "KRW",
        "RUB", "ZAR", "SGD", "HKD", "AED", "SAR", "THB", "IDR", "MYR", "PHP", "ILS", "UAH",
    ]

    private static func codes(in text: NormalizedText) -> [String: Int] {
        var votes: [String: Int] = [:]
        for line in text.lines {
            for word in line.text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
                let upper = word.uppercased()
                if upper.count == 3, isoCodes.contains(upper), word == word.uppercased() { votes[upper, default: 0] += 1 }
            }
        }
        return votes
    }

    // MARK: - Symbols

    /// Longest first so `R$` and `US$` are not read as a bare `$`.
    private static let symbols: [(mark: String, currencies: [String])] = [
        ("US$", ["USD"]), ("CA$", ["CAD"]), ("C$", ["CAD"]), ("AU$", ["AUD"]), ("A$", ["AUD"]),
        ("MX$", ["MXN"]), ("NZ$", ["NZD"]), ("HK$", ["HKD"]), ("S$", ["SGD"]), ("R$", ["BRL"]),
        ("€", ["EUR"]), ("£", ["GBP"]), ("₹", ["INR"]), ("₩", ["KRW"]), ("₽", ["RUB"]), ("₺", ["TRY"]),
        ("₪", ["ILS"]), ("฿", ["THB"]), ("₫", ["VND"]), ("zł", ["PLN"]), ("Kč", ["CZK"]),
        ("$", ["USD", "MXN", "CAD", "AUD", "ARS", "CLP", "COP"]),
        ("¥", ["JPY", "CNY"]), ("￥", ["JPY", "CNY"]),
        ("kr", ["SEK", "NOK", "DKK"]),
    ]

    private static let symbolPattern: NSRegularExpression = {
        let marks = symbols.map { NSRegularExpression.escapedPattern(for: $0.mark) }.joined(separator: "|")
        // A symbol only counts when it touches a number: `$ 12.50`, `12,50 €`, `kr 99`.
        return try! NSRegularExpression(
            pattern: "(?:(\(marks))\\s?\\d)|(?:\\d\\s?(\(marks))(?![A-Za-z]))"
        )
    }()

    /// Symbols nobody uses for anything else, so `TOTAL (€)` counts without a number beside it.
    private static let standaloneMarks = ["€", "£", "₹", "₩", "₽", "₺", "₪", "฿", "₫"]

    /// Votes for single-currency symbols, and counts of each shared-symbol candidate list.
    private static func symbols(in text: NormalizedText) -> (specific: [String: Int], shared: [[String]: Int]) {
        var specific: [String: Int] = [:]
        var shared: [[String]: Int] = [:]
        for line in text.lines {
            let ns = line.text as NSString
            for mark in standaloneMarks where line.text.contains(mark) {
                guard let entry = symbols.first(where: { $0.mark == mark }) else { continue }
                specific[entry.currencies[0], default: 0] += 1
            }
            for match in symbolPattern.matches(in: line.text, range: NSRange(location: 0, length: ns.length)) {
                let range = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
                let mark = ns.substring(with: range)
                guard let entry = symbols.first(where: { $0.mark == mark }) else { continue }
                if standaloneMarks.contains(mark) { continue }
                if entry.currencies.count == 1 { specific[entry.currencies[0], default: 0] += 1 }
                else { shared[entry.currencies, default: 0] += 1 }
            }
        }
        return (specific, shared)
    }

    // MARK: - Numeric format

    /// Currencies usually printed with a decimal comma.
    private static let commaDecimalCurrencies: Set<String> = ["ARS", "CLP", "COP", "SEK", "NOK", "DKK"]

    /// `,` or `.` according to the original (pre-normalization) amounts, or `nil` if mixed or absent.
    private static func decimalSeparator(in text: NormalizedText) -> Character? {
        var comma = 0, dot = 0
        for line in text.lines {
            comma += count(#"\d,\d{2}(?!\d)"#, in: line.original)
            dot += count(#"\d\.\d{2}(?!\d)"#, in: line.original)
        }
        if comma > 0, dot == 0 { return "," }
        if dot > 0, comma == 0 { return "." }
        return nil
    }

    private static func count(_ pattern: String, in text: String) -> Int {
        RegexCache.shared.count(pattern, in: text)
    }
}
