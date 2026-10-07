import ReceiptKit
import SwiftUI
import UIKit

@main
struct ReceiptScannerApp: App {
    private let environment = AppEnvironment.make()

    var body: some Scene {
        WindowGroup {
            switch environment {
            case .ready(let flow, let history):
                ScanHomeView(flow: flow, history: history)
                    .tint(ReceiptStyle.accent)
            case .storageUnavailable(let message):
                ContentUnavailableView {
                    Label("Storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Receipts cannot be saved or loaded right now. \(message)")
                }
                .tint(ReceiptStyle.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ReceiptStyle.canvas)
            }
        }
    }
}

enum ReceiptStyle {
    static let deepBlue = Color(red: 21 / 255, green: 49 / 255, blue: 159 / 255)
    static let electricBlue = Color(red: 32 / 255, green: 89 / 255, blue: 208 / 255)
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.61, green: 0.77, blue: 1, alpha: 1)
            : UIColor(red: 0.09, green: 0.24, blue: 0.65, alpha: 1)
    })
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.09, blue: 0.18, alpha: 1)
            : UIColor(red: 0.95, green: 0.97, blue: 1, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.17, blue: 0.29, alpha: 1)
            : .white
    })
    static let mint = Color(red: 0.75, green: 0.98, blue: 0.89)
    static let hero = LinearGradient(colors: [deepBlue, electricBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
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
