import ReceiptKit
import SwiftUI

@main
struct ReceiptScannerApp: App {
    private let environment = AppEnvironment.make()

    var body: some Scene {
        WindowGroup {
            switch environment {
            case .ready(let flow, let history):
                ScanHomeView(flow: flow, history: history)
            case .storageUnavailable(let message):
                ContentUnavailableView {
                    Label("Storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Receipts cannot be saved or loaded right now. \(message)")
                }
            }
        }
    }
}

/// Builds the long-lived objects once. If the store cannot open, the app says so instead of
/// silently falling back to memory and losing receipts.
@MainActor
enum AppEnvironment {
    case ready(ScanFlow, HistoryStore)
    case storageUnavailable(String)

    static func make() -> AppEnvironment {
        do {
            let repository = SwiftDataReceiptRepository(modelContainer: try ReceiptSchema.makeContainer())
            let flow = ScanFlow(
                processor: ReceiptProcessor(ocr: VisionOCRService(), parser: DefaultReceiptParser()),
                repository: repository
            )
            return .ready(flow, HistoryStore(repository: repository))
        } catch {
            return .storageUnavailable(error.localizedDescription)
        }
    }
}
