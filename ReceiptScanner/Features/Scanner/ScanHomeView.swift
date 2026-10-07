import ReceiptKit
import SwiftUI

/// Entry point that presents the scanner and shows the flow state.
struct ScanHomeView: View {
    let flow: ScanFlow

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch flow.state {
                case .idle, .scanning:
                    ContentUnavailableView(
                        "No receipts yet",
                        systemImage: "doc.text.viewfinder",
                        description: Text("Scan a receipt to get started.")
                    )
                case .processing:
                    ProgressView("Reading receipt…")
                case .review(let parsed, _):
                    Text(parsed.rawText.isEmpty ? "No text found." : parsed.rawText)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Something went wrong", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Dismiss") { flow.reset() }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Scan", systemImage: "camera.viewfinder") { startScan() }
                        .disabled(isBusy)
                }
            }
            .fullScreenCover(isPresented: isScanning) {
                DocumentScannerView { outcome in
                    Task { await flow.handle(outcome) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var isBusy: Bool {
        if case .processing = flow.state { true } else { false }
    }

    private var isScanning: Binding<Bool> {
        Binding(
            get: { if case .scanning = flow.state { true } else { false } },
            set: { if !$0, case .scanning = flow.state { flow.reset() } }
        )
    }

    private func startScan() {
        guard DocumentScannerView.isSupported else {
            Task { await flow.handle(.failed(.cameraUnavailable)) }
            return
        }
        flow.startScan()
    }
}
