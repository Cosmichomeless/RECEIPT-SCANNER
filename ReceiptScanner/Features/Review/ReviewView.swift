import ReceiptKit
import SwiftUI

/// Shows what OCR found and lets the user correct or fill every field before saving.
struct ReviewView: View {
    let flow: ScanFlow
    let image: CGImage
    @State private var draft: ReceiptDraft
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field { case merchant, total }

    init(flow: ScanFlow, parsed: ParsedReceipt, image: CGImage) {
        self.flow = flow
        self.image = image
        _draft = State(initialValue: ReceiptDraft(parsed))
    }

    var body: some View {
        Form {
            Section {
                Label("Check the details before saving", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ReceiptStyle.accent)
            }
            .listRowBackground(ReceiptStyle.surface)
            Section("Scan") {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .padding(.vertical, 8)
                    .accessibilityElement()
                    .accessibilityLabel("Scanned receipt")
                    .accessibilityIdentifier("scanThumbnail")
            }
            .listRowBackground(ReceiptStyle.surface)

            Section("Merchant") {
                TextField("Merchant", text: $draft.merchant, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .merchant)
                    .submitLabel(.done)
                    .onChange(of: draft.merchant) { _, name in
                        // A multi-line field would turn Return into a line break; treat it as Done.
                        guard name.contains("\n") else { return }
                        draft.merchant = name.replacingOccurrences(of: "\n", with: " ")
                            .trimmingCharacters(in: .whitespaces)
                        focusedField = nil
                    }
                hint(for: .missingMerchant, "Not detected. Type the merchant name.")
            }
            .listRowBackground(ReceiptStyle.surface)

            Section("Date") {
                Toggle("Has a date", isOn: hasDate)
                if draft.date != nil {
                    DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                }
                ForEach(draft.dateSuggestions, id: \.self) { suggestion in
                    Button(suggestion.formatted) { draft.date = suggestion }
                }
                hint(for: .missingDate, "Not detected. Set it if you need it, or leave it empty.")
                if !draft.dateSuggestions.isEmpty {
                    Text("This date can be read in more than one way. Pick the right one.")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            .listRowBackground(ReceiptStyle.surface)

            Section("Total") {
                TextField("0.00", text: $draft.totalText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .total)
                hint(for: .missingTotal, "Not detected. Type the total.")
                if draft.problems.contains(.invalidTotal) {
                    Text("Enter a positive amount, for example 84.37.")
                        .font(.footnote).foregroundStyle(.red)
                }
            }
            .listRowBackground(ReceiptStyle.surface)

            Section("Currency") {
                Picker("Currency", selection: $draft.currencyCode) {
                    Text("Not set").tag("")
                    ForEach(currencyOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                if !draft.currencySuggestions.isEmpty {
                    Text("The symbol on the receipt fits several currencies.")
                        .font(.footnote).foregroundStyle(.orange)
                }
                hint(for: .missingCurrency, "Not detected. Choose the currency.")
            }
            .listRowBackground(ReceiptStyle.surface)

            Section {
                DisclosureGroup("Recognized text") {
                    Text(draft.rawText.isEmpty ? "No text found." : draft.rawText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
                if let timings = flow.lastTimings {
                    DisclosureGroup("Diagnostics") {
                        LabeledContent("Image", value: "\(timings.imageWidth)×\(timings.imageHeight)")
                        LabeledContent("Text recognition", value: timings.ocr.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)))
                        LabeledContent("Parsing", value: timings.parsing.formatted(.units(allowed: [.milliseconds, .microseconds], width: .narrow)))
                    }
                    .font(.footnote)
                }
            }
            .listRowBackground(ReceiptStyle.surface)

            if let error = flow.saveError {
                Section { Text(error).foregroundStyle(.red) }
                    .listRowBackground(ReceiptStyle.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ReceiptStyle.canvas)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Discard", role: .destructive) { flow.reset() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    isSaving = true
                    Task {
                        await flow.save(draft)
                        isSaving = false
                    }
                }
                .disabled(!draft.canSave || isSaving)
            }
        }
    }

    /// A note shown only when the parser could not fill the field.
    @ViewBuilder
    private func hint(for issue: ParsingIssue, _ message: LocalizedStringKey) -> some View {
        if draft.issues.contains(issue) {
            Text(message).font(.footnote).foregroundStyle(.orange)
        }
    }

    /// Suggestions from the parser first, then common codes, always including the current value.
    private var currencyOptions: [String] {
        var seen = Set<String>()
        let candidates = draft.currencySuggestions + [draft.currencyCode] + Self.commonCurrencies
        return candidates.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static let commonCurrencies = [
        "EUR", "USD", "GBP", "CHF", "JPY", "CAD", "AUD", "NZD", "SEK", "NOK", "DKK",
        "PLN", "CZK", "HUF", "RON", "MXN", "BRL", "ARS", "CLP", "COP", "PEN",
        "CNY", "HKD", "INR", "KRW", "SGD", "TRY", "ZAR", "AED"
    ]

    private var hasDate: Binding<Bool> {
        Binding(
            get: { draft.date != nil },
            set: { draft.date = $0 ? (draft.date ?? CalendarDate(Date(), in: .current)) : nil }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { (draft.date ?? CalendarDate(Date(), in: .current)).date(in: .current) ?? Date() },
            set: { draft.date = CalendarDate($0, in: .current) }
        )
    }
}

private extension CalendarDate {
    var formatted: String {
        (date(in: .current) ?? Date()).formatted(date: .long, time: .omitted)
    }
}
