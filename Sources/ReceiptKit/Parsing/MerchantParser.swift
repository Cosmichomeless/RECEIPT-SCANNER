import Foundation

public struct MerchantCandidate: Equatable, Sendable {
    public let name: String
    public let lineIndex: Int
    public let score: Int
}

/// Picks the merchant name from the header of a receipt.
///
/// The merchant is almost always one of the first lines. Lines that are clearly something
/// else (address, phone, tax ID, postal code, URL, date, amount, receipt boilerplate) are
/// rejected; the rest are scored by position and how much they look like a name.
public struct MerchantParser: Sendable {
    /// Only the top of the receipt is searched.
    public static let headerLines = 8
    public static let acceptanceThreshold = 10

    public init() {}

    public func parse(_ text: NormalizedText) -> String? {
        candidates(in: text).first.map(\.name)
    }

    /// Plausible names, best first.
    public func candidates(in text: NormalizedText) -> [MerchantCandidate] {
        var result: [MerchantCandidate] = []
        var seen = 0
        for line in text.lines {
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            seen += 1
            if seen > Self.headerLines { break }
            guard let name = Self.clean(trimmed), !Self.isNoise(name) else { continue }
            let score = Self.score(name, position: seen - 1)
            if score >= Self.acceptanceThreshold {
                result.append(MerchantCandidate(name: name, lineIndex: line.index, score: score))
            }
        }
        // Stable: earlier lines win ties.
        return result.enumerated()
            .sorted { ($0.element.score, $1.offset) > ($1.element.score, $0.offset) }
            .map(\.element)
    }

    // MARK: - Scoring

    private static func score(_ name: String, position: Int) -> Int {
        var score = max(0, 30 - position * 5)
        let letters = name.filter(\.isLetter)
        let upper = letters.filter(\.isUppercase)
        if letters.count >= 3 { score += 10 }
        if letters.count >= 2, upper.count == letters.count { score += 5 }
        // Mostly letters: names rarely carry many digits or symbols.
        let ratio = Double(letters.count) / Double(max(name.count, 1))
        if ratio >= 0.8 { score += 10 } else if ratio < 0.5 { score -= 15 }
        if name.count > 40 { score -= 15 }
        if name.contains(where: \.isASCIIDigit) { score -= 10 }
        if companySuffixes.contains(where: { containsWord(name, $0) }) { score += 5 }
        return score
    }

    /// Strips decoration (`*** NAME ***`, `--- NAME ---`) and collapses spaces.
    static func clean(_ line: String) -> String? {
        let decoration = CharacterSet(charactersIn: "*-_=#~.:|/\\+<>[]()\"' ")
        var name = line.trimmingCharacters(in: decoration)
        // "S.A." and "S.L." end in a period that belongs to the name.
        if line.hasSuffix("."), name.range(of: #"(?<![A-Za-z])[A-Za-z]\.[A-Za-z]$"#, options: .regularExpression) != nil {
            name += "."
        }
        return name.contains(where: \.isLetter) ? name : nil
    }

    // MARK: - Rejection

    static func isNoise(_ line: String) -> Bool {
        let upper = line.uppercased()
        if line.filter(\.isLetter).count < 2 { return true }
        if matches(urlPattern, line) || matches(emailPattern, line) { return true }
        if matches(phonePattern, line) || matches(postalPattern, line) { return true }
        if matches(datePattern, line) || matches(timePattern, line) || matches(amountPattern, line) { return true }
        if taxIDKeywords.contains(where: { containsWord(upper, $0) }) { return true }
        if boilerplate.contains(where: { containsWord(upper, $0) }) { return true }
        if isAddress(upper) { return true }
        return false
    }

    private static func isAddress(_ upper: String) -> Bool {
        if streetWords.contains(where: { containsWord(upper, $0) }) { return true }
        // Words that also appear in business names ("Plaza Cafe") only count next to a number.
        if upper.contains(where: \.isASCIIDigit), ambiguousStreetWords.contains(where: { containsWord(upper, $0) }) {
            return true
        }
        return matches(#"^(NO\.?|NUM\.?|#)\s*\d+"#, upper)
    }

    private static let streetWords = [
        "STREET", "AVENUE", "ROAD", "BOULEVARD", "BLVD", "HIGHWAY", "SUITE", "FLOOR",
        "CALLE", "AVENIDA", "AVDA", "CARRETERA", "CTRA", "COLONIA", "STRASSE", "STRAßE",
    ]
    private static let ambiguousStreetWords = [
        "ST", "AVE", "RD", "LANE", "DRIVE", "WAY", "HWY", "STE", "UNIT", "PLAZA", "SQUARE",
        "AV", "PASEO", "CAMINO", "BARRIO", "COL", "RUE", "VIA", "PIAZZA",
    ]
    private static let taxIDKeywords = [
        "VAT", "TAX", "RFC", "NIF", "CIF", "NIT", "RUT", "CUIT", "EIN", "GST", "ABN", "IVA", "TIN", "SIRET", "TVA", "USt",
    ].map { $0.uppercased() }
    private static let boilerplate = [
        "RECEIPT", "INVOICE", "TICKET", "FACTURA", "RECIBO", "COMPROBANTE", "SIMPLIFICADA", "WELCOME", "BIENVENIDO",
        "THANK", "GRACIAS", "TOTAL", "SUBTOTAL", "CASHIER", "CAJERO", "CAJA", "TEL", "PHONE", "FAX", "ORDER", "TABLE",
        "MESA", "COPY", "DUPLICATE", "CUSTOMER", "SERVER", "DATE", "FECHA", "TIME", "HORA",
    ]
    private static let companySuffixes = ["INC", "LLC", "LTD", "CORP", "CO", "GMBH", "SA", "SL", "SAS", "SRL", "CIA"]

    // MARK: - Patterns

    private static let urlPattern = #"(?i)(https?://|www\.|\b[a-z0-9-]+\.(com|net|org|io|es|mx|co|app|shop)\b)"#
    private static let emailPattern = #"[^\s@]+@[^\s@]+\.[A-Za-z]{2,}"#
    /// 7+ digits once separators are ignored, or a formatted number like (555) 123-4567.
    private static let phonePattern = #"(\+?\d[\d ().\-]{6,}\d)"#
    /// A 5-digit code counts only at the start of the line or after a comma or state code
    /// (`28013 Madrid`, `Springfield, IL 62704`), so `STATION 12345` stays a name.
    private static let postalPattern =
        #"(?:^|,\s*|(?<![A-Za-z])[A-Z]{2}\s)\d{5}(-\d{4})?(?![0-9])|(?<![A-Za-z0-9])[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}(?![A-Za-z0-9])"#
    private static let datePattern = #"(?<![0-9])\d{1,4}[-/.]\d{1,2}[-/.]\d{2,4}(?![0-9])"#
    private static let timePattern = #"(?<![0-9])\d{1,2}:\d{2}(:\d{2})?\s?([AaPp][Mm])?"#
    private static let amountPattern = #"(?<![0-9])\d+[.,]\d{2}(?![0-9])"#

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func containsWord(_ text: String, _ word: String) -> Bool {
        text.range(
            of: "(?<![A-Za-z0-9])\(NSRegularExpression.escapedPattern(for: word))(?![A-Za-z0-9])",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
