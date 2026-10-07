import Foundation

/// Compiles each pattern once. `String.range(of:options: .regularExpression)` recompiles the
/// pattern on every call, which dominated parsing time when scanning every header line.
final class RegexCache: @unchecked Sendable {
    static let shared = RegexCache()

    private let lock = NSLock()
    private var cache: [String: NSRegularExpression] = [:]

    func regex(_ pattern: String, caseInsensitive: Bool = false) -> NSRegularExpression? {
        let key = (caseInsensitive ? "i:" : "s:") + pattern
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        guard let compiled = try? NSRegularExpression(
            pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : []
        ) else { return nil }
        cache[key] = compiled
        return compiled
    }

    func matches(_ pattern: String, in text: String, caseInsensitive: Bool = false) -> Bool {
        count(pattern, in: text, caseInsensitive: caseInsensitive, limit: 1) > 0
    }

    func count(_ pattern: String, in text: String, caseInsensitive: Bool = false, limit: Int = .max) -> Int {
        guard let regex = regex(pattern, caseInsensitive: caseInsensitive) else { return 0 }
        let range = NSRange(location: 0, length: (text as NSString).length)
        if limit == 1 { return regex.firstMatch(in: text, range: range) == nil ? 0 : 1 }
        return regex.numberOfMatches(in: text, range: range)
    }
}
