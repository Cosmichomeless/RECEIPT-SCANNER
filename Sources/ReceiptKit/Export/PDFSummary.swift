import CoreGraphics
import CoreText
import Foundation

/// A printable summary: one row per receipt and the totals per currency. A4, as many pages as needed.
public struct PDFSummary: Sendable {
    public var title: String
    /// A line under the title, for example the date range.
    public var subtitle: String?
    private let locale: Locale
    private let calendar: Calendar

    public init(title: String? = nil, subtitle: String? = nil, locale: Locale = .current, calendar: Calendar = .current) {
        self.title = title ?? Localized.string("Receipts", locale: locale)
        self.subtitle = subtitle
        self.locale = locale
        self.calendar = calendar
    }

    public func data(for receipts: [Receipt]) -> Data {
        let output = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: Layout.width, height: Layout.height)
        let info = [kCGPDFContextTitle as String: title] as CFDictionary
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, info)
        else { return Data() }

        var page = Page(context: context, locale: locale)
        page.begin()
        page.text(title, x: Layout.margin, y: Layout.height - Layout.margin - 18, size: 20, bold: true)
        page.cursor = Layout.height - Layout.margin - 46
        if let subtitle {
            page.text(subtitle, x: Layout.margin, y: page.cursor, size: 11, gray: 0.35)
            page.cursor -= 16
        }
        page.text(Localized.string("\(receipts.count) receipts", locale: locale),
                  x: Layout.margin, y: page.cursor, size: 11, gray: 0.35)
        page.cursor -= 26
        page.header()

        for receipt in receipts {
            if page.cursor < Layout.margin + 40 {
                page.end()
                page.begin()
                page.cursor = Layout.height - Layout.margin
                page.header()
            }
            page.row(
                date: receipt.date.map { $0.formatted(.dateTime.day().month(.twoDigits).year().locale(locale)) } ?? "",
                merchant: receipt.merchant,
                vat: receipt.tax.amount.map { money($0, receipt.currencyCode) } ?? "",
                total: money(receipt.total, receipt.currencyCode)
            )
        }

        // Totals per currency, in order of first appearance.
        var order: [String] = []
        var totals: [String: (total: Decimal, vat: Decimal)] = [:]
        for receipt in receipts {
            if totals[receipt.currencyCode] == nil { order.append(receipt.currencyCode) }
            let sum = totals[receipt.currencyCode] ?? (0, 0)
            totals[receipt.currencyCode] = (sum.total + receipt.total, sum.vat + (receipt.tax.amount ?? 0))
        }
        if page.cursor < Layout.margin + 30 + CGFloat(order.count) * 16 {
            page.end()
            page.begin()
            page.cursor = Layout.height - Layout.margin
        }
        page.cursor -= 8
        page.rule()
        for code in order {
            guard let sum = totals[code] else { continue }
            page.row(date: "", merchant: Localized.string("Total \(code)", locale: locale), vat: money(sum.vat, code), total: money(sum.total, code), bold: true)
        }
        page.end()
        context.closePDF()
        return output as Data
    }

    private func money(_ value: Decimal, _ code: String) -> String {
        value.formatted(.currency(code: code).locale(locale))
    }

    // MARK: - Drawing

    private enum Layout {
        static let width: CGFloat = 595
        static let height: CGFloat = 842
        static let margin: CGFloat = 40
        static let dateX = margin
        static let merchantX = margin + 80
        static let vatRight = width - margin - 110
        static let totalRight = width - margin
        static let rowHeight: CGFloat = 18
    }

    private struct Page {
        let context: CGContext
        let locale: Locale
        var cursor: CGFloat = 0
        private var number = 0

        init(context: CGContext, locale: Locale) {
            self.context = context
            self.locale = locale
        }

        mutating func begin() {
            number += 1
            context.beginPDFPage(nil)
        }

        func end() {
            text("\(number)", x: Layout.width / 2, y: Layout.margin - 20, size: 9, gray: 0.5, align: .center)
            context.endPDFPage()
        }

        mutating func header() {
            text(Localized.string("Date", locale: locale), x: Layout.dateX, y: cursor, size: 9, bold: true, gray: 0.35)
            text(Localized.string("Merchant", locale: locale), x: Layout.merchantX, y: cursor, size: 9, bold: true, gray: 0.35)
            text(Localized.string("VAT", locale: locale), x: Layout.vatRight, y: cursor, size: 9, bold: true, gray: 0.35, align: .right)
            text(Localized.string("Total", locale: locale), x: Layout.totalRight, y: cursor, size: 9, bold: true, gray: 0.35, align: .right)
            cursor -= 8
            rule()
        }

        mutating func rule() {
            context.setStrokeColor(CGColor(gray: 0.75, alpha: 1))
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: Layout.margin, y: cursor))
            context.addLine(to: CGPoint(x: Layout.width - Layout.margin, y: cursor))
            context.strokePath()
            cursor -= Layout.rowHeight - 4
        }

        mutating func row(date: String, merchant: String, vat: String, total: String, bold: Bool = false) {
            text(date, x: Layout.dateX, y: cursor, size: 10, bold: bold)
            text(merchant, x: Layout.merchantX, y: cursor, size: 10, bold: bold, maxWidth: Layout.vatRight - Layout.merchantX - 80)
            text(vat, x: Layout.vatRight, y: cursor, size: 10, bold: bold, align: .right)
            text(total, x: Layout.totalRight, y: cursor, size: 10, bold: bold, align: .right)
            cursor -= Layout.rowHeight
        }

        enum Alignment { case left, center, right }

        func text(
            _ string: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false, gray: CGFloat = 0.1,
            align: Alignment = .left, maxWidth: CGFloat? = nil
        ) {
            guard !string.isEmpty else { return }
            let font = CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: gray, alpha: 1),
            ]
            var line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
            if let maxWidth, CTLineGetTypographicBounds(line, nil, nil, nil) > maxWidth {
                let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: attributes))
                line = CTLineCreateTruncatedLine(line, maxWidth, .end, ellipsis) ?? line
            }
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let left = switch align {
            case .left: x
            case .center: x - width / 2
            case .right: x - width
            }
            context.textPosition = CGPoint(x: left, y: y)
            CTLineDraw(line, context)
        }
    }
}
