import ReceiptKit
import SwiftUI

/// Entry point that presents the scanner and shows the flow state.
struct ScanHomeView: View {
    let flow: ScanFlow
    let history: HistoryStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch flow.state {
                case .idle, .scanning:
                    HistoryView(history: history)
                case .processing:
                    ProgressView("Reading receipt…")
                case .review(let parsed, let image):
                    ReviewView(flow: flow, parsed: parsed, image: image)
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
            .task(id: flow.savedCount) { await history.reload() }
            .toolbar {
                if isIdle {
                    #if DEBUG
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Try sample receipt", systemImage: "doc.text.image") { scanSample() }
                    }
                    #endif
                    ToolbarItem(placement: .primaryAction) {
                        Button("Scan", systemImage: "camera.viewfinder") { startScan() }
                    }
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

    /// Scan actions only make sense from the history; hide them while reviewing or processing.
    private var isIdle: Bool {
        if case .idle = flow.state { true } else { false }
    }

    private var isScanning: Binding<Bool> {
        Binding(
            get: { if case .scanning = flow.state { true } else { false } },
            set: { if !$0, case .scanning = flow.state { flow.reset() } }
        )
    }

    #if DEBUG
    /// Debug builds only: feeds a drawn receipt through the same path as a camera capture.
    private func scanSample() {
        guard let image = SampleReceipt.makeImage() else { return }
        Task { await flow.handle(.captured(image)) }
    }
    #endif

    private func startScan() {
        guard DocumentScannerView.isSupported else {
            Task { await flow.handle(.failed(.cameraUnavailable)) }
            return
        }
        flow.startScan()
    }
}
