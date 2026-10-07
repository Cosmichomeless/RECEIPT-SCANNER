# Release notes and checklist

Version **0.1.0** (build 1), the MVP. Version numbers live in `project.yml` (`MARKETING_VERSION`,
`CURRENT_PROJECT_VERSION`); run `xcodegen generate` after changing them.

## What is in 0.1.0

- Document scanning with VisionKit; on-device text recognition with Vision (no network use).
- Text normalization and heuristic parsing of merchant, date, total and currency, with ambiguity reported
  rather than guessed (English and Spanish keywords).
- Review screen to correct or fill any field before saving.
- Local history with SwiftData: list, detail, delete, persists across launches.
- 23-receipt fixture suite and regression tests; per-field accuracy report; parse-time budget.
- Debug builds only: "Try sample receipt" for running the flow without a camera.

## Known limitations

See [performance.md](performance.md) and [ocr-and-parsing.md](ocr-and-parsing.md). In short: real-world
accuracy is unmeasured (fixtures are clean text), German/French are not supported, space-grouped thousands and
dates with OCR errors are not repaired, scanned images are not kept, and there is no export, sync or search.

## Checklist before shipping a build

Automated, run from the repo root:

- [ ] `swift test` passes (all suites).
- [ ] `xcodegen generate` leaves `ReceiptScanner.xcodeproj` unchanged in git.
- [ ] `xcodebuild -project ReceiptScanner.xcodeproj -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` succeeds.

Manual, on a physical device with a Release or TestFlight build:

- [ ] Scan at least five real receipts (supermarket, restaurant, fuel, hardware, one crumpled or faded).
  Note which fields needed correction; add the failures as fixtures.
- [ ] Record **Review → Diagnostics** numbers and update [performance.md](performance.md) (OCR time, image size).
  Check memory in Instruments during a scan.
- [ ] Camera permission prompt shows the text from `NSCameraUsageDescription`; denying it shows the "camera
  unavailable" message, not a crash.
- [ ] Save, relaunch, confirm the history; delete a receipt.
- [ ] Airplane mode: whole flow still works.
- [ ] Debug-only sample action is absent in the Release build.

Distribution (requires the developer's own Apple account; none of this is done by the repo or its automated checks):

- [ ] Set the signing team and a unique bundle identifier (currently `dev.cosmichomeless.ReceiptScanner`).
- [ ] Add an app icon (none yet) and, for the App Store, a privacy policy and the "Data Not Collected"
  privacy answers (the app has no network use or analytics).
- [ ] Archive, upload to TestFlight, and test the uploaded build.
- [ ] Only then submit for review.

## Tagging

After the final merge to `main`: `git tag -a v0.1.0 -m "MVP"` and `git push origin v0.1.0`, then create the
GitHub release from the notes above.
