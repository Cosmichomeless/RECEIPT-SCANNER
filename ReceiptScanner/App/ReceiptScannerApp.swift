import ReceiptKit
import SwiftUI

@main
struct ReceiptScannerApp: App {
    @State private var flow = ScanFlow(
        processor: ReceiptProcessor(ocr: PendingOCRService(), parser: RawTextParser())
    )

    var body: some Scene {
        WindowGroup {
            ScanHomeView(flow: flow)
        }
    }
}
