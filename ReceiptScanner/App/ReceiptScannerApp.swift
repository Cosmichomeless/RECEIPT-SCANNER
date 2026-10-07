import ReceiptKit
import SwiftUI

@main
struct ReceiptScannerApp: App {
    @State private var flow = ScanFlow(
        processor: ReceiptProcessor(ocr: VisionOCRService(), parser: DefaultReceiptParser())
    )

    var body: some Scene {
        WindowGroup {
            ScanHomeView(flow: flow)
        }
    }
}
