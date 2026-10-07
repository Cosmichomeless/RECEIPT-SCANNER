#if DEBUG
import CoreGraphics
import UIKit

/// A drawn receipt for trying the whole flow where there is no camera (Simulator, demos).
/// It runs through the real Vision OCR and parser. Only compiled into debug builds.
enum SampleReceipt {
    static let lines = [
        "NORTHLINE HARDWARE", "Market Street 12", "Date 6 Oct 2026", "",
        "HEX KEY SET        18.99", "WOOD GLUE           6.49", "SANDPAPER PACK     12.40",
        "SUBTOTAL           37.88", "TAX                 3.79", "TOTAL              41.67",
        "VISA ****4471",
    ]

    @MainActor
    static func makeImage() -> CGImage? {
        let size = CGSize(width: 1200, height: 1500)
        let renderer = UIGraphicsImageRenderer(size: size, format: .init(for: .init(displayScale: 1)))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 54, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 70, y: 90 + CGFloat(index) * 110), withAttributes: attributes)
            }
        }
        return image.cgImage
    }
}
#endif
