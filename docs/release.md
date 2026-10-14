# Release notes and checklist

Version **1.1.0** (build 1), the first App Store candidate (1.0.0 was the portfolio MVP). Version numbers live in `project.yml` (`MARKETING_VERSION`,
`CURRENT_PROJECT_VERSION`); run `xcodegen generate` after changing them.

## What is in 1.1.0

- Document scanning with VisionKit; on-device text recognition with Vision (no network use).
- Text normalization and heuristic parsing of merchant, date, total and currency, with ambiguity reported
  rather than guessed (English, Spanish, German and French keywords).
- Review screen to correct or fill any field before saving.
- Local history with SwiftData: list, detail, delete, persists across launches.
- 89-receipt fixture suite (es, de, fr, en) and regression tests; per-field accuracy report; parse-time budget.
- Export to CSV and PDF (and a ZIP of kept scans, unused until scans can be kept) through the share sheet.
- VAT, tax breakdown and merchant tax ID extraction.
- Spanish, French and German localization; privacy manifest and privacy policy.
- Debug builds only: "Try sample receipt" for running the flow without a camera.

## Known limitations

See [performance.md](performance.md) and [ocr-and-parsing.md](ocr-and-parsing.md). In short: real-world
accuracy on real tickets is unmeasured (fixtures are clean text; see `scripts/measure-accuracy.sh`), dates with OCR errors are not repaired, scanned images are not kept, and there is no sync or search.

## Checklist before shipping a build

Automated, run from the repo root:

These three run in `.github/workflows/ci.yml` on every push to `main` and every pull request; confirm the run is green
on the commit you tag. Locally:

- [ ] `swift test` passes (all suites) on a Mac. CI skips the real-Vision OCR tests (see `.github/workflows/ci.yml`), so this local run is the one that covers them.
- [ ] `xcodegen generate` leaves `ReceiptScanner.xcodeproj` unchanged in git.
- [ ] `xcodebuild -project ReceiptScanner.xcodeproj -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` succeeds.

Manual, on a physical device with a Release or TestFlight build:

- [ ] Scan at least five real receipts (supermarket, restaurant, fuel, hardware, one crumpled or faded).
  Note which fields needed correction; add the failures as fixtures, or measure a batch with
  `scripts/ocr-tickets.sh` and `scripts/measure-accuracy.sh`.
- [ ] Go through [device-testing.md](device-testing.md).
- [ ] Record **Review → Diagnostics** numbers and update [performance.md](performance.md) (OCR time, image size).
  Check memory in Instruments during a scan.
- [ ] Camera permission prompt shows the text from `NSCameraUsageDescription`; denying it shows the "camera
  unavailable" message, not a crash.
- [ ] Save, relaunch, confirm the history; delete a receipt.
- [ ] Airplane mode: whole flow still works.
- [ ] Debug-only sample action is absent in the Release build.

Distribution (requires the developer's own Apple account; none of this is done by the repo or its automated checks):

- [ ] Set the signing team and a unique bundle identifier (currently `dev.cosmichomeless.ReceiptScanner`).
- [x] Include an app icon in the asset catalog.
- [x] Privacy manifest (`ReceiptScanner/PrivacyInfo.xcprivacy`) and policy text (`docs/privacy.md`).
- [ ] Publish the policy and support page (GitHub Pages from `/docs`, see [app-store/README.md](app-store/README.md)) and enter
  the URLs, the "Data Not Collected" privacy answers, the age rating and the EU trader status in App Store Connect.
  Everything to paste is in [app-store/](app-store/).
- [ ] Archive, upload to TestFlight, and test the uploaded build.
- [ ] Only then submit for review.

## Tagging

Tag the verified main commit as `v1.1.0` and push that tag to GitHub. A GitHub Release is a separate,
optional publication; no App Store submission or TestFlight upload is implied by this tag.
