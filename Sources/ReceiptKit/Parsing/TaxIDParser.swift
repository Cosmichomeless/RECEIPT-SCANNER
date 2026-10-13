import Foundation

/// Finds the Spanish tax number (NIF, CIF or NIE) of the merchant.
///
/// A number is accepted when its check character is valid, or when the line says `CIF`,
/// `NIF` or `NIE`; a phone number or a ticket number is never taken for one. The result is
/// written without separators: `B12345674`.
public struct TaxIDParser: Sendable {
    public init() {}

    public func parse(_ text: NormalizedText) -> String? {
        var labelled: String?
        for line in text.lines {
            let hasLabel = Self.hasLabel(line.text)
            for candidate in Self.candidates(in: line.text) {
                if Self.isValid(candidate) { return candidate }
                if hasLabel, labelled == nil { labelled = candidate }
            }
        }
        return labelled
    }

    // MARK: - Matching

    private static let labelPattern = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z])(?:C\.?I\.?F|N\.?I\.?F|N\.?I\.?E|CIF/NIF)\b"#, options: [.caseInsensitive]
    )
    /// Company: letter + 7 digits + digit or letter. Foreigner (NIE): X/Y/Z + 7 digits + letter.
    private static let letterPattern = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])([ABCDEFGHJNPQRSUVWXYZ])[-. ]?(\d{7})[-. ]?([0-9A-Z])(?![A-Za-z0-9])"#
    )
    /// Individual (DNI): 8 digits + letter.
    private static let dniPattern = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])(\d{8})[-. ]?([A-Z])(?![A-Za-z0-9])"#
    )

    private static func hasLabel(_ line: String) -> Bool {
        labelPattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil
    }

    private static func candidates(in line: String) -> [String] {
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        let letters = letterPattern.matches(in: line, range: range).map { match in
            (1...3).map { ns.substring(with: match.range(at: $0)) }.joined()
        }
        let dnis = dniPattern.matches(in: line, range: range).map { match in
            (1...2).map { ns.substring(with: match.range(at: $0)) }.joined()
        }
        return letters + dnis
    }

    // MARK: - Check characters

    static func isValid(_ id: String) -> Bool {
        let chars = Array(id)
        guard chars.count == 9 else { return false }
        if chars[0].isASCIIDigit { return isValidDNI(chars) }
        if "XYZ".contains(chars[0]) { return isValidNIE(chars) }
        return isValidCIF(chars)
    }

    private static let controlLetters = Array("TRWAGMYFPDXBNJZSQVHLCKE")

    private static func isValidDNI(_ chars: [Character]) -> Bool {
        guard let number = Int(String(chars[0..<8])) else { return false }
        return controlLetters[number % 23] == chars[8]
    }

    private static func isValidNIE(_ chars: [Character]) -> Bool {
        let prefix = ["X": "0", "Y": "1", "Z": "2"][String(chars[0])]!
        guard let number = Int(prefix + String(chars[1..<8])) else { return false }
        return controlLetters[number % 23] == chars[8]
    }

    private static func isValidCIF(_ chars: [Character]) -> Bool {
        let digits = chars[1..<8].compactMap(\.wholeNumberValue)
        guard digits.count == 7 else { return false }
        var sum = 0
        for (index, digit) in digits.enumerated() {
            if index % 2 == 0 {
                let doubled = digit * 2
                sum += doubled / 10 + doubled % 10
            } else {
                sum += digit
            }
        }
        let control = (10 - sum % 10) % 10
        let letter = Array("JABCDEFGHI")[control]
        let last = chars[8]
        // Entities that must use a letter (K, P, Q, S, N, W), a digit (A, B, E, H), or either.
        switch chars[0] {
        case "P", "Q", "S", "N", "W", "R": return last == letter
        case "A", "B", "E", "H": return last == Character(String(control))
        default: return last == letter || last == Character(String(control))
        }
    }
}
