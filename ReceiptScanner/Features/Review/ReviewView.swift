import ReceiptKit
import SwiftUI

/// Shows what OCR found and lets the user correct or fill every field before saving.
struct ReviewView: View {
    let flow: ScanFlow
    let image: CGImage
    @State private var draft: ReceiptDraft
    @State private var isSaving = false

    init(flow: ScanFlow, parsed: ParsedReceipt, image: CGImage) {
        self.flow = flow
        self.image = image
        _draft = State(initialValue: ReceiptDraft(parsed))
    }

    var body: some View {
        Form {
            Section("Merchant") {
                TextField("Merchant", text: $draft.merchant)
                    .textInputAutocapitalization(.words)
                hint(for: .missingMerchant, "Not detected. Type the merchant name.")
            }

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

            Section("Total") {
                TextField("0.00", text: $draft.totalText)
                    .keyboardType(.decimalPad)
                hint(for: .missingTotal, "Not detected. Type the total.")
                if draft.problems.contains(.invalidTotal) {
                    Text("Enter a positive amount, for example 84.37.")
                        .font(.footnote).foregroundStyle(.red)
                }
            }

            Section("Currency") {
                TextField("EUR", text: $draft.currencyCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                if !draft.currencySuggestions.isEmpty {
                    Picker("Suggestions", selection: $draft.currencyCode) {
                        Text("—").tag("")
                        ForEach(draft.currencySuggestions, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("The symbol on the receipt fits several currencies.")
                        .font(.footnote).foregroundStyle(.orange)
                }
                hint(for: .missingCurrency, "Not detected. Enter a 3-letter code such as EUR or USD.")
                if draft.problems.contains(.invalidCurrency) {
                    Text("Use a 3-letter ISO code.").font(.footnote).foregroundStyle(.red)
                }
            }

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

            if let error = flow.saveError {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
