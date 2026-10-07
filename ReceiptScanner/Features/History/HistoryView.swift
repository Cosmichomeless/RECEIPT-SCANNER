import ReceiptKit
import SwiftUI

/// Saved receipts, newest first. Tapping one reopens it.
struct HistoryView: View {
    let history: HistoryStore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(ReceiptStyle.mint)
                        .accessibilityHidden(true)
                    Text("Your receipts, in one place")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Scan, review and keep every detail close at hand.")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(ReceiptStyle.hero, in: RoundedRectangle(cornerRadius: 24))
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))

            if history.receipts.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(ReceiptStyle.accent)
                            .accessibilityHidden(true)
                        Text("No receipts yet").font(.headline)
                        Text("Scan a receipt to get started.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(ReceiptStyle.surface)
                }
            } else {
                Section("History") {
                    ForEach(history.receipts) { receipt in
                        NavigationLink(value: receipt) { HistoryRow(receipt: receipt) }
                            .listRowBackground(ReceiptStyle.surface)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { history.receipts[$0].id }
                        Task { for id in ids { await history.delete(id) } }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ReceiptStyle.canvas)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(ReceiptStyle.accent)
                    .frame(width: 42, height: 42)
                    .background(ReceiptStyle.canvas, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading) {
                Text(receipt.merchant).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let date = receipt.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if dynamicTypeSize.isAccessibilitySize {
                    total
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
                total
            }
        }
    }

    private var total: some View {
        Text(receipt.total, format: .currency(code: receipt.currencyCode))
            .font(.headline)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ReceiptDetailView: View {
    let receipt: Receipt
    let history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Receipt total", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(ReceiptStyle.mint)
                    Text(receipt.total, format: .currency(code: receipt.currencyCode))
                        .font(.largeTitle.bold())
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(ReceiptStyle.hero, in: RoundedRectangle(cornerRadius: 20))
                .listRowBackground(Color.clear)
            }
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
        .scrollContentBackground(.hidden)
        .background(ReceiptStyle.canvas)
        .navigationTitle(receipt.merchant)
        .navigationBarTitleDisplayMode(.inline)
    }
}
