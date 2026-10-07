# Changelog

## 0.1.0 — MVP

- Scan receipts with the VisionKit document camera and read them on the device with Vision.
- Parse merchant, date, total and currency; report ambiguous or missing fields instead of guessing.
- Review and correct the parsed fields before saving.
- Save receipts locally with SwiftData; history list, detail and delete.
- Fixture-based regression suite (23 receipts), accuracy report and performance guards.
- Documentation: architecture, OCR and parsing trade-offs, performance and limitations, privacy and storage,
  demo script and release checklist.
