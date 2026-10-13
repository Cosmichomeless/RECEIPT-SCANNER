import ReceiptKit
import SwiftUI

/// Chooses what to export and hands the file to the share sheet (Mail, Files, AirDrop).
struct ExportView: View {
    let receipts: [Receipt]
    @Environment(\.dismiss) private var dismiss

    @State private var options = Options()
    @State private var outcome: Outcome = .preparing
    @State private var directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)

    struct Options: Hashable {
        var format: ExportFormat = .csv
        var limitDates = false
        var from = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        var to = Date()

        var range: ExportRange { limitDates ? ExportRange(from: from, to: to) : .all }
    }

    private enum Outcome: Equatable {
        case preparing
        case ready(URL, count: Int)
        case empty
        case failed(String)
    }

    private var hasImages: Bool { receipts.contains { $0.imagePath != nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $options.format) {
                        Text("CSV").tag(ExportFormat.csv)
                        Text("PDF").tag(ExportFormat.pdf)
                        if hasImages { Text("Images").tag(ExportFormat.images) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("exportFormat")
                    Text(formatNote).font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(ReceiptStyle.surface)

                Section("Dates") {
                    Toggle("Limit to a date range", isOn: $options.limitDates)
                    if options.limitDates {
                        DatePicker("From", selection: $options.from, in: ...options.to, displayedComponents: .date)
                        DatePicker("To", selection: $options.to, in: options.from..., displayedComponents: .date)
                    }
                }
                .listRowBackground(ReceiptStyle.surface)

                Section {
                    switch outcome {
                    case .preparing:
                        ProgressView("Preparing…")
                    case .ready(let url, let count):
                        Text("\(count) receipts ready to share.")
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("shareExport")
                    case .empty:
                        Text(options.format == .images ? LocalizedStringKey("No scans were kept for these dates.") : LocalizedStringKey("No receipts in these dates."))
                            .foregroundStyle(.secondary)
                    case .failed(let message):
                        Text(message).foregroundStyle(.red)
                    }
                }
                .listRowBackground(ReceiptStyle.surface)
            }
            .scrollContentBackground(.hidden)
            .background(ReceiptStyle.canvas)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task(id: options) { await prepare() }
            .onDisappear { try? FileManager.default.removeItem(at: directory) }
        }
    }

    private var formatNote: LocalizedStringKey {
        switch options.format {
        case .csv: "One row per receipt with date, merchant, tax ID, base, VAT and total. Opens in Excel and Numbers."
        case .pdf: "A printable list with totals per currency."
        case .images: "A ZIP with the scans you chose to keep."
        }
    }

    private func prepare() async {
        outcome = .preparing
        let options = options, receipts = receipts, directory = directory
        // The directory is cleaned between runs so only the latest export is shared.
        let result = await Task.detached(priority: .userInitiated) { () -> Outcome in
            try? FileManager.default.removeItem(at: directory)
            let exporter = ReceiptExporter()
            do {
                let url = try exporter.write(options.format, receipts: receipts, range: options.range, to: directory) { path in
                    FileManager.default.contents(atPath: URL.applicationSupportDirectory.appendingPathComponent(path).path)
                }
                return .ready(url, count: exporter.selection(from: receipts, in: options.range).count)
            } catch ReceiptExporter.ExportError.noReceipts, ReceiptExporter.ExportError.noImages {
                return .empty
            } catch {
                return .failed(error.localizedDescription)
            }
        }.value
        guard !Task.isCancelled else { return }
        outcome = result
    }
}
