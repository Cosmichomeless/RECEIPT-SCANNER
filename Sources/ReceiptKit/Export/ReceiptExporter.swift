import Foundation

public enum ExportFormat: String, CaseIterable, Sendable {
    case csv, pdf
    /// A ZIP with the retained scans. Only possible for receipts that have an `imagePath`.
    case images

    var fileExtension: String { self == .csv ? "csv" : self == .pdf ? "pdf" : "zip" }
}

/// Inclusive range of days. A `nil` end is open.
public struct ExportRange: Hashable, Sendable {
    public var from: Date?
    public var to: Date?

    public static let all = ExportRange()

    public init(from: Date? = nil, to: Date? = nil) {
        self.from = from
        self.to = to
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        if let from, date < calendar.startOfDay(for: from) { return false }
        if let to, let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)), date >= end { return false }
        return true
    }
}

/// Selects receipts and writes an export file to a directory, ready for the share sheet.
public struct ReceiptExporter: Sendable {
    public enum ExportError: Error, Equatable {
        case noReceipts
        case noImages
    }

    private let locale: Locale
    private let calendar: Calendar

    public init(locale: Locale = .current, calendar: Calendar = .current) {
        self.locale = locale
        self.calendar = calendar
    }

    /// Receipts inside the range, oldest first. A receipt without a date counts by the day it was saved.
    public func selection(from receipts: [Receipt], in range: ExportRange) -> [Receipt] {
        receipts
            .filter { range.contains($0.date ?? $0.createdAt, calendar: calendar) }
            .sorted { ($0.date ?? $0.createdAt, $0.createdAt) < ($1.date ?? $1.createdAt, $1.createdAt) }
    }

    /// Writes the file and returns its URL. `imageLoader` returns the bytes for a receipt's `imagePath`.
    public func write(
        _ format: ExportFormat,
        receipts: [Receipt],
        range: ExportRange = .all,
        to directory: URL,
        now: Date = Date(),
        imageLoader: @Sendable (String) -> Data? = { _ in nil }
    ) throws -> URL {
        let chosen = selection(from: receipts, in: range)
        guard !chosen.isEmpty else { throw ExportError.noReceipts }

        let data: Data
        switch format {
        case .csv:
            data = CSVExporter(locale: locale, calendar: calendar).data(for: chosen)
        case .pdf:
            data = PDFSummary(subtitle: describe(range), locale: locale, calendar: calendar).data(for: chosen)
        case .images:
            var entries: [ZipArchive.Entry] = []
            for receipt in chosen {
                guard let path = receipt.imagePath, let image = imageLoader(path) else { continue }
                let fileExtension = (path as NSString).pathExtension
                entries.append(.init(name: imageName(for: receipt, index: entries.count + 1, extension: fileExtension), data: image))
            }
            guard !entries.isEmpty else { throw ExportError.noImages }
            data = try ZipArchive.make(entries, modified: now, calendar: calendar)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("receipts-\(isoDay(now)).\(format.fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Names and labels

    private func imageName(for receipt: Receipt, index: Int, extension ext: String) -> String {
        // ASCII only: older unzip tools and some mail gateways mangle other names.
        let folded = receipt.merchant.folding(options: [.diacriticInsensitive], locale: nil)
        var merchant = ""
        for scalar in folded.unicodeScalars {
            let keep = scalar.isASCII && CharacterSet.alphanumerics.contains(scalar)
            if keep { merchant.unicodeScalars.append(scalar) } else if !merchant.hasSuffix("-") { merchant.append("-") }
        }
        let trimmed = String(merchant.prefix(30)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let day = (receipt.date ?? receipt.createdAt).formatted(.iso8601.year().month().day())
        return String(format: "%03d-%@-%@.%@", index, day, trimmed.isEmpty ? "receipt" : trimmed, ext.isEmpty ? "jpg" : ext)
    }

    private func describe(_ range: ExportRange) -> String? {
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        switch (range.from, range.to) {
        case let (from?, to?): return "\(from.formatted(style)) – \(to.formatted(style))"
        case let (from?, nil): return Localized.string("From \(from.formatted(style))", locale: locale)
        case let (nil, to?): return Localized.string("Until \(to.formatted(style))", locale: locale)
        case (nil, nil): return nil
        }
    }

    private func isoDay(_ date: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }
}
