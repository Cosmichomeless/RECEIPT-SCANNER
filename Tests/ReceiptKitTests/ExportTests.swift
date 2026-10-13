import Foundation
import PDFKit
import Testing
@testable import ReceiptKit

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: 12))!
}

private func receipt(
    _ merchant: String = "MERCADONA",
    date: Date? = day(2026, 10, 6),
    total: Decimal = 7,
    currency: String = "EUR",
    tax: TaxBreakdown = TaxBreakdown(),
    taxID: String? = nil,
    imagePath: String? = nil
) -> Receipt {
    Receipt(merchant: merchant, date: date, total: total, currencyCode: currency, tax: tax, taxID: taxID,
            rawText: "", createdAt: day(2026, 10, 7), imagePath: imagePath)
}

@Suite struct CSVExporterTests {
    private let english = CSVExporter(locale: Locale(identifier: "en_US"), calendar: utc)
    private let spanish = CSVExporter(locale: Locale(identifier: "es_ES"), calendar: utc)

    @Test func headerAndRow() {
        let r = receipt(total: 7, tax: TaxBreakdown(base: Decimal(string: "6.36"), rate: 10, amount: Decimal(string: "0.64")), taxID: "A46103834")
        let lines = english.csv(for: [r]).components(separatedBy: "\r\n")
        #expect(lines[0] == "date,merchant,tax_id,base,vat_rate,vat,total,currency,category")
        #expect(lines[1] == "2026-10-06,MERCADONA,A46103834,6.36,10,0.64,7.00,EUR,")
        #expect(lines[2] == "")
    }

    @Test func spanishLocaleUsesSemicolonAndDecimalComma() {
        let r = receipt(total: Decimal(string: "1234.5")!, tax: TaxBreakdown(rate: Decimal(string: "5.5")))
        #expect(spanish.separator == ";")
        #expect(english.separator == ",")
        let row = spanish.csv(for: [r]).components(separatedBy: "\r\n")[1]
        #expect(row == "2026-10-06;MERCADONA;;;5,5;;1234,50;EUR;")
    }

    @Test func unknownValuesAreEmpty() {
        let row = english.csv(for: [receipt(date: nil)]).components(separatedBy: "\r\n")[1]
        #expect(row == ",MERCADONA,,,,,7.00,EUR,")
    }

    @Test func quotesCommasQuotesAndLineBreaks() {
        let r = receipt("BAR \"EL PATIO\", S.L.\nMadrid")
        let row = english.csv(for: [r]).components(separatedBy: "\r\n")[1]
        #expect(row.hasPrefix("2026-10-06,\"BAR \"\"EL PATIO\"\", S.L.\nMadrid\",,"))
    }

    @Test func semicolonIsQuotedInSpanishFormatButNotComma() {
        #expect(spanish.csv(for: [receipt("A;B")]).contains(";\"A;B\";"))
        #expect(spanish.csv(for: [receipt("A,B")]).contains(";A,B;"))
    }

    @Test(arguments: ["=SUM(A1)", "+1", "-1", "@cmd", "\tx"])
    func formulaPrefixesAreNeutralized(_ merchant: String) {
        let row = english.csv(for: [receipt(merchant)]).components(separatedBy: "\r\n")[1]
        #expect(row.contains(",'" + merchant + ","))
    }

    @Test func dataStartsWithUTF8ByteOrderMark() {
        let data = english.data(for: [receipt("CAFÉ ÑANDÚ")])
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(String(decoding: data.dropFirst(3), as: UTF8.self).contains("CAFÉ ÑANDÚ"))
    }
}

@Suite struct ZipArchiveTests {
    @Test func crc32MatchesKnownValue() {
        #expect(CRC32.checksum(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(CRC32.checksum(Data()) == 0)
    }

    @Test func structureHasEntriesAndEndRecord() throws {
        let zip = try ZipArchive.make([.init(name: "a.txt", data: Data("hello".utf8)), .init(name: "ñ.txt", data: Data())], calendar: utc)
        #expect(Array(zip.prefix(4)) == [0x50, 0x4B, 0x03, 0x04])
        let end = zip.suffix(22)
        #expect(Array(end.prefix(4)) == [0x50, 0x4B, 0x05, 0x06])
        #expect(end[end.startIndex + 10] == 2)   // entries in the directory
    }

    #if os(macOS)
    @Test func systemUnzipAcceptsAndExtractsTheArchive() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Data((0..<5000).map { UInt8($0 % 251) })
        let zip = try ZipArchive.make([.init(name: "one.bin", data: payload), .init(name: "dir/cafe.txt", data: Data("hola".utf8))], calendar: utc)
        let file = directory.appendingPathComponent("test.zip")
        try zip.write(to: file)

        func run(_ arguments: [String]) throws -> (status: Int32, output: String) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            process.waitUntilExit()
            return (process.terminationStatus, output)
        }
        let check = try run(["-tq", file.path])
        #expect(check.status == 0, "\(check.output)")
        let extract = try run(["-qo", file.path, "-d", directory.appendingPathComponent("out").path])
        #expect(extract.status == 0, "\(extract.output)")
        #expect(try Data(contentsOf: directory.appendingPathComponent("out/one.bin")) == payload)
    }
    #endif

    @Test func emptyArchiveIsJustTheEndRecord() throws {
        #expect(try ZipArchive.make([]).count == 22)
    }
}

@Suite struct PDFSummaryTests {
    private func document(_ receipts: [Receipt]) throws -> PDFDocument {
        let data = PDFSummary(subtitle: "Oct 2026", locale: Locale(identifier: "en_US"), calendar: utc).data(for: receipts)
        return try #require(PDFDocument(data: data))
    }

    @Test func listsReceiptsAndTotalsPerCurrency() throws {
        let doc = try document([
            receipt("MERCADONA", total: 7, tax: TaxBreakdown(amount: Decimal(string: "0.64"))),
            receipt("TACOS", total: 100, currency: "MXN"),
            receipt("DIA", total: Decimal(string: "22.88")!),
        ])
        #expect(doc.pageCount == 1)
        let text = try #require(doc.string)
        #expect(text.contains("MERCADONA"))
        #expect(text.contains("TACOS"))
        #expect(text.contains("Oct 2026"))
        #expect(text.contains("3 receipts"))
        #expect(text.contains("Total EUR"))
        #expect(text.contains("€29.88"))
        #expect(text.contains("Total MXN"))
    }

    @Test func longListsContinueOnNewPages() throws {
        let many = (0..<120).map { receipt("SHOP \($0)", total: Decimal($0 + 1)) }
        let doc = try document(many)
        #expect(doc.pageCount >= 3)
        let text = try #require(doc.string)
        #expect(text.contains("SHOP 0"))
        #expect(text.contains("SHOP 119"))
    }

    @Test func emptyListStillMakesAPage() throws {
        #expect(try document([]).pageCount == 1)
    }
}

@Suite struct ReceiptExporterTests {
    private let exporter = ReceiptExporter(locale: Locale(identifier: "en_US"), calendar: utc)

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString)")
    }

    @Test func selectionFiltersByInclusiveDaysAndSortsOldestFirst() {
        let receipts = [
            receipt("C", date: day(2026, 10, 20)),
            receipt("A", date: day(2026, 10, 1)),
            receipt("B", date: day(2026, 10, 15)),
            receipt("OUT", date: day(2026, 11, 1)),
        ]
        let range = ExportRange(from: day(2026, 10, 1), to: day(2026, 10, 20))
        #expect(exporter.selection(from: receipts, in: range).map(\.merchant) == ["A", "B", "C"])
        #expect(exporter.selection(from: receipts, in: .all).count == 4)
        #expect(exporter.selection(from: receipts, in: ExportRange(from: day(2026, 10, 16))).map(\.merchant) == ["C", "OUT"])
        #expect(exporter.selection(from: receipts, in: ExportRange(to: day(2026, 10, 1))).map(\.merchant) == ["A"])
    }

    @Test func receiptWithoutDateCountsByTheDayItWasSaved() {
        let r = receipt("NODATE", date: nil)   // saved 2026-10-07
        #expect(exporter.selection(from: [r], in: ExportRange(from: day(2026, 10, 7), to: day(2026, 10, 7))).count == 1)
        #expect(exporter.selection(from: [r], in: ExportRange(to: day(2026, 10, 6))).isEmpty)
    }

    @Test func writesCSVAndPDFFiles() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = day(2026, 10, 13)
        let csv = try exporter.write(.csv, receipts: [receipt()], to: directory, now: now)
        let pdf = try exporter.write(.pdf, receipts: [receipt()], to: directory, now: now)
        #expect(csv.lastPathComponent == "receipts-2026-10-13.csv")
        #expect(pdf.lastPathComponent == "receipts-2026-10-13.pdf")
        #expect(try Data(contentsOf: csv).count > 3)
        #expect(PDFDocument(url: pdf)?.pageCount == 1)
    }

    @Test func emptySelectionThrows() {
        let directory = temporaryDirectory()
        #expect(throws: ReceiptExporter.ExportError.noReceipts) {
            try exporter.write(.csv, receipts: [receipt(date: day(2025, 1, 1))], range: ExportRange(from: day(2026, 1, 1)), to: directory)
        }
    }

    @Test func imagesZipOnlyHoldsReceiptsWithImages() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let receipts = [
            receipt("CAFÉ / BAR", imagePath: "a/one.jpg"),
            receipt("NO IMAGE"),
            receipt("MISSING FILE", imagePath: "gone.jpg"),
        ]
        let url = try exporter.write(.images, receipts: receipts, to: directory, imageLoader: { path in
            path == "a/one.jpg" ? Data("jpeg".utf8) : nil
        })
        #expect(url.pathExtension == "zip")
        let zip = try Data(contentsOf: url)
        #expect(zip.suffix(22)[zip.suffix(22).startIndex + 10] == 1)
        #expect(String(decoding: zip, as: UTF8.self).contains("001-2026-10-06-CAFE-BAR.jpg"))
    }

    @Test func imagesExportWithoutImagesThrows() {
        #expect(throws: ReceiptExporter.ExportError.noImages) {
            try exporter.write(.images, receipts: [receipt()], to: temporaryDirectory())
        }
    }
}
