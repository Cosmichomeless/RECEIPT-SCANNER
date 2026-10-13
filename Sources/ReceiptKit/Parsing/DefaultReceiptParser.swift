import Foundation

/// Normalizes the OCR text and runs every field parser over it. Unknown or uncertain
/// fields stay `nil` and are listed in `issues`, so the review screen knows what to ask.
public struct DefaultReceiptParser: ReceiptParser {
    private let normalizer = TextNormalizer()
    private let totalParser = TotalParser()
    private let taxParser = TaxParser()
    private let taxIDParser = TaxIDParser()
    private let merchantParser = MerchantParser()
    private let dateParser: DateParser
    private let currencyParser: CurrencyParser

    public init(locale: Locale = .current) {
        dateParser = DateParser(order: .forLocale(locale))
        currencyParser = CurrencyParser(locale: locale)
    }

    public func parse(_ ocr: OCRResult) -> ParsedReceipt {
        let text = normalizer.normalize(ocr)
        var receipt = ParsedReceipt(rawText: ocr.rawText)

        receipt.merchant = merchantParser.parse(text)
        if receipt.merchant == nil { receipt.issues.append(.missingMerchant) }

        switch dateParser.parse(text) {
        case .found(let date): receipt.date = date
        case .ambiguous(let candidates): receipt.issues.append(.ambiguousDate(candidates: candidates))
        case .notFound: receipt.issues.append(.missingDate)
        }

        receipt.total = totalParser.parse(text)
        if receipt.total == nil { receipt.issues.append(.missingTotal) }

        switch currencyParser.parse(text) {
        case .found(let code): receipt.currencyCode = code
        case .ambiguous(let candidates): receipt.issues.append(.ambiguousCurrency(candidates: candidates))
        case .notFound: receipt.issues.append(.missingCurrency)
        }

        receipt.tax = taxParser.parse(text, total: receipt.total)
        if let tax = receipt.tax, !tax.isConsistent(withTotal: receipt.total) { receipt.issues.append(.taxMismatch) }
        receipt.merchantTaxID = taxIDParser.parse(text)
        return receipt
    }
}
