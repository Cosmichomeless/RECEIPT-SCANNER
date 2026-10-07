import ReceiptKit
import SwiftUI
import VisionKit

/// VisionKit document camera. Reports exactly one `CaptureOutcome` per presentation:
/// the first page scanned, cancellation, or an error.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onOutcome: (CaptureOutcome) -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onOutcome: onOutcome) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onOutcome: (CaptureOutcome) -> Void

        init(onOutcome: @escaping (CaptureOutcome) -> Void) {
            self.onOutcome = onOutcome
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0, let image = scan.imageOfPage(at: 0).cgImage else {
                onOutcome(.failed(.scannerFailed("The scan contained no pages.")))
                return
            }
            onOutcome(.captured(image))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onOutcome(.cancelled)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onOutcome(.failed(.scannerFailed(error.localizedDescription)))
        }
    }
}
