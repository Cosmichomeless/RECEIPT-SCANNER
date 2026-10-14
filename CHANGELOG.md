# Changelog

## 1.1.0 — 2026-10-14

- Export: CSV, PDF and a ZIP of kept scans through the share sheet, optionally limited to a date range. The Images
  format only appears when a receipt has a kept scan; the app does not keep scans yet, so today it is CSV and PDF.
- Tax: VAT, tax breakdown and merchant tax ID are extracted from receipts and included in the export.
- Localization: the app is translated into Spanish, French and German (`Localizable.xcstrings`,
  `InfoPlist.xcstrings`).
- App Store compliance: `PrivacyInfo.xcprivacy` (no tracking, no collected data, no required-reason APIs) and a
  privacy policy in English and Spanish (`docs/privacy.md`).
- CI: `.github/workflows/ci.yml` runs `swift test`, checks that `xcodegen generate` leaves the project unchanged, and
  builds the app.
- App Store Connect metadata (listing text in en/es/fr/de, privacy and age-rating answers, review notes) in
  `docs/app-store/`.
- Memory: after a scan is processed, the review state keeps a 1200 px image instead of the full-resolution
  capture (about 48 MB at 12 MP), and captures delivered while one is processing are ignored.
- `docs/device-testing.md`: checklist for what must be tried on a physical iPhone.
- Parsers: totals that say they include tax (`TOTAL INCL VAT`, `Gesamt inkl. MwSt`, `IVA incluido`) are still the
  total; sums of savings (`TOTAL DESCUENTOS`, `TOTAL REMISES`, `RABATT`) are not; `BETRAG` and `A PAYER` count as
  total labels; German and French month names (`12 März 2026`, `6 févr. 2026`) are read; `T0TAL`-style keywords with
  digit look-alikes are repaired; `STATION TOTAL` is accepted as a merchant; 2.1 % VAT is a known rate.
- Fixtures: 89 receipts (was 28) across es, de, fr, en, with pharmacy and taxi categories. Accuracy report adds
  tax and tax ID, and a breakdown by locale and category.
- `scripts/ocr-tickets.sh` and `scripts/measure-accuracy.sh` measure real tickets outside the repository.

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
