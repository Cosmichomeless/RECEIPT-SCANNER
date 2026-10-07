import ReceiptKit
import SwiftUI

/// Saved receipts, newest first. Tapping one reopens it.
struct HistoryView: View {
    let history: HistoryStore

    var body: some View {
        Group {
            if history.receipts.isEmpty {
                ContentUnavailableView(
                    "No receipts yet",
                    systemImage: "doc.text.viewfinder",
                    description: Text("Scan a receipt to get started.")
                )
            } else {
                List {
                    ForEach(history.receipts) { receipt in
                        NavigationLink(value: receipt) { HistoryRow(receipt: receipt) }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { history.receipts[$0].id }
                        Task { for id in ids { await history.delete(id) } }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let error = history.loadError {
                Text(error).font(.footnote).padding(8).background(.red.opacity(0.15), in: .capsule).padding()
            }
        }
        .navigationDestination(for: Receipt.self) { ReceiptDetailView(receipt: $0, history: history) }
    }
}

private struct HistoryRow: View {
    let receipt: Receipt

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(receipt.merchant).font(.headline)
                if let date = receipt.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(receipt.total, format: .currency(code: receipt.currencyCode))
                .monospacedDigit()
        }
    }
}

struct ReceiptDetailView: View {
    let receipt: Receipt
    let history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            LabeledContent("Merchant", value: receipt.merchant)
            LabeledContent("Date") {
                if let date = receipt.date { Text(date, format: .dateTime.day().month().year()) } else { Text("—") }
            }
            LabeledContent("Total") { Text(receipt.total, format: .currency(code: receipt.currencyCode)) }
            LabeledContent("Currency", value: receipt.currencyCode)
            LabeledContent("Saved") { Text(receipt.createdAt, format: .dateTime) }
            Section {
                DisclosureGroup("Recognized text") {
                    Text(receipt.rawText.isEmpty ? "No text." : receipt.rawText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }
            Section {
                Button("Delete receipt", role: .destructive) {
                    Task {
                        await history.delete(receipt.id)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(receipt.merchant)
        .navigationBarTitleDisplayMode(.inline)
    }
}
