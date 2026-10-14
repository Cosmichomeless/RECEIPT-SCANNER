<div align="center">

# Receipt Scanner

**Turn paper receipts into editable records, entirely on your iPhone.**

![Status: MVP, device validation pending](https://img.shields.io/badge/status-MVP%20validation-yellow) ![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS-blue) ![License: MIT](https://img.shields.io/badge/license-MIT-green)

[Try it](#try-it) · [Screenshots](#screenshots) · [Architecture](#architecture) · [Documentation](#documentation)

</div>

[![Receipt Scanner icon beside real receipt history and review screenshots](docs/screenshots/00-showcase.png)](#screenshots)

Receipt Scanner uses VisionKit and on-device Vision OCR to extract a merchant, date, total and currency. You review uncertain fields before anything is saved to a local SwiftData history. There is no public demo or App Store build yet.

## What it includes

- **Scan and recognize:** capture a receipt with VisionKit; text recognition runs on the device.
- **Review before saving:** correct any field, see a scan thumbnail, and leave ambiguous values unset instead of guessing.
- **Local history:** open, relaunch and delete saved receipts; scanned images are not retained.
- **Export:** share a CSV or PDF of your receipts (with VAT and tax ID) through the share sheet, optionally for a date range.
- **Localized:** English, Spanish, French and German.
- **Offline workflow:** OCR, parsing and persistence require no external service.
- **Reproducible demo:** a Debug-only sample receipt runs through real OCR on the simulator.

## Try it

Requires Xcode with an iPhone simulator. Build with one command, then open ReceiptScanner.xcodeproj and run the ReceiptScanner scheme. In a Debug build, use More → Try sample receipt; a physical iPhone is needed for the camera.

    xcodebuild -project ReceiptScanner.xcodeproj -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

## Screenshots

The cover pairs the real app icon with crops of the screens below. Captured on an iPhone 17 Pro simulator with the sample receipt. The UI test and [demo walkthrough](docs/demo.md) describe the same flow; these PNGs are committed so the README renders on GitHub. Select an image to view it at full size. After updating the committed PNGs, rebuild the cover with Pillow:

    python3 docs/screenshots/build-showcase.py

| **History** | **Review before saving** |
| --- | --- |
| [![Blue receipt history with a saved sample purchase](docs/screenshots/01-history.png)](docs/screenshots/01-history.png) | [![Review form and scanned sample receipt thumbnail](docs/screenshots/02-review.png)](docs/screenshots/02-review.png) |
| **Saved detail** | **Dark appearance** |
| [![Saved receipt details and delete action](docs/screenshots/03-detail.png)](docs/screenshots/03-detail.png) | [![Receipt history in dark appearance](docs/screenshots/04-dark-history.png)](docs/screenshots/04-dark-history.png) |

## Architecture

```mermaid
flowchart LR
    Camera[VisionKit capture] -->|CGImage| OCR[Vision OCR]
    OCR -->|Recognized text| Parser[Heuristic parser]
    Parser -->|Draft and warnings| Review[SwiftUI review]
    Review -->|Validated receipt| Store[SwiftData history]
```

- **Capture and OCR:** VisionKit obtains an image; Vision recognizes text without an upload.
- **Parsing and review:** independent, testable stages surface missing or ambiguous fields for correction.
- **Persistence:** only confirmed fields and raw text enter SwiftData; the image is discarded.

## Design decisions

| Decision | Why | Cost |
| --- | --- | --- |
| **On-device OCR instead of an API** | Works offline and keeps receipt images on the phone. | Accuracy and speed depend on the device and scan quality. |
| **Heuristics instead of a generative parser** | Results and regression fixtures are inspectable. | Novel receipt layouts need new rules or manual correction. |
| **Discard images instead of keeping them** | Reduces storage and sensitive data retention. | A past scan cannot be visually rechecked later. |

## Known limitations

- Accuracy on real-world receipts has not been measured; the 89 fixtures are clean text written by hand (es, de, fr, en), not a field benchmark. `scripts/ocr-tickets.sh` and `scripts/measure-accuracy.sh` measure real tickets once available.
- OCR-damaged dates and tips added by hand are not repaired; the app asks instead.
- There is no search, account or sync; history stays on this device. Export is manual, through the share sheet.
- Physical-device camera, permission, memory and TestFlight checks in [the release checklist](docs/release.md) are still pending; an App Store release is not promised.

## Quality

- 157 Swift tests pass, including the 89-receipt fixture suite and OCR/performance checks on macOS.
- FullFlowUITests exercises sample → review → correction → save → detail → delete on a simulator; it does not test a real camera.
- `.github/workflows/ci.yml` runs the tests, the project-sync check and a build on GitHub Actions. No public deployment is claimed.

## Documentation

| Document | Contents |
| --- | --- |
| [Product flows](docs/product-flows.md) | Capture, review and history behavior. |
| [Architecture](docs/architecture.md) | Component boundaries and data flow. |
| [OCR and parsing](docs/ocr-and-parsing.md) | Heuristics, ambiguities and trade-offs. |
| [Performance](docs/performance.md) | Fixture accuracy, timings and limits. |
| [Privacy and storage](docs/privacy-and-storage.md) | What remains on the device. |
| [Demo and release](docs/demo.md) · [Checklist](docs/release.md) | Walkthrough and remaining device checks. |
| [App Store pack](docs/app-store/README.md) | Listing text (en/es/fr/de), privacy and age-rating answers, review notes. |
| [Privacy policy](docs/privacy.md) · [Support](docs/index.md) | Published with GitHub Pages from `/docs`. |

## Repository layout

    ReceiptScanner/        SwiftUI app, scanning, review and history
    Sources/ReceiptKit/     OCR, parsing, flow and persistence interfaces
    Tests/                  Swift package tests and fixtures
    ReceiptScannerUITests/  Simulator end-to-end UI test
    docs/                   Architecture, evidence and release checklist

## Distribution and license

Version 1.1.0 is the App Store candidate; listing text, privacy answers and review notes are in [docs/app-store](docs/app-store/). No TestFlight or App Store build has been published yet. Signing, privacy answers and physical-device checks are documented in [the release checklist](docs/release.md). Licensed under [MIT](LICENSE).
