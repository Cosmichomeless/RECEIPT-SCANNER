# Changelog

## 1.0.0 — Portfolio MVP

- Review: currency is a menu instead of free text, the keyboard has a Done button and dismisses on drag, a thumbnail of
  the scan is shown, and a long merchant name wraps.
- Home: Scan and the debug menu are hidden while a scan is being reviewed.
- Simulator UI test that runs the whole flow (`ReceiptScannerUITests`).
- Icon-driven blue interface for history, review and detail, with dark appearance and accessible text sizes.
- A 1024 px app icon in the asset catalog.

### Original MVP scope

- Scan receipts with the VisionKit document camera and read them on the device with Vision.
- Parse merchant, date, total and currency; report ambiguous or missing fields instead of guessing.
- Review and correct the parsed fields before saving.
- Save receipts locally with SwiftData; history list, detail and delete.
- Fixture-based regression suite (23 receipts), accuracy report and performance guards.
- Documentation: architecture, OCR and parsing trade-offs, performance and limitations, privacy and storage,
  demo script and release checklist.
