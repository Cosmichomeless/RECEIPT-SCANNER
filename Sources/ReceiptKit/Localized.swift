import Foundation

/// Looks up the strings ReceiptKit produces (errors, PDF labels) in the language of a locale.
///
/// `String(localized:locale:)` only formats values with the locale; the language comes from the
/// process. Resolving the `.lproj` here keeps output tied to the locale it was asked for, which
/// is also what makes it testable.
enum Localized {
    static func string(_ value: String.LocalizationValue, locale: Locale = .current) -> String {
        String(localized: value, bundle: bundle(for: locale))
    }

    private static func bundle(for locale: Locale) -> Bundle {
        let code = Bundle.preferredLocalizations(from: Bundle.module.localizations, forPreferences: [locale.identifier]).first
        guard let code,
              let path = Bundle.module.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .module }
        return bundle
    }
}
