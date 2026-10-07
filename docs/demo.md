# Demo: scan, correct, history

A five-minute walkthrough of the whole MVP. It works without a camera by using the sample receipt in
debug builds; on a device you can scan a real one.

## Setup

```sh
xcodegen generate
open ReceiptScanner.xcodeproj      # run the ReceiptScanner scheme on an iPhone simulator or device
```

Or from the terminal: `xcodebuild -project ReceiptScanner.xcodeproj -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`.

## Script

1. **Empty history.** The home screen reads "No receipts yet". Nothing is stored before the first save.
2. **Scan.**
   - Device: tap the camera button and capture a receipt with the document scanner.
   - Simulator (debug build): tap **⋯ → Try sample receipt**. A drawn receipt goes through the same path as a
     capture: real Vision OCR, then the parser.
3. **Processing** ("Reading receipt…") takes a fraction of a second.
4. **Review.** For the sample, the parser fills in:
   - Merchant: `NORTHLINE HARDWARE`
   - Date: 6 Oct 2026
   - Total: `41.67`
   - Currency: **empty and flagged**. The receipt prints no currency, so the app asks instead of guessing.

   Expand **Recognized text** to see what OCR returned, and **Diagnostics** for image size and timings.
5. **Correct.** Pick `EUR` from the **Currency** menu (Save is disabled until merchant, total and currency are valid).
   A thumbnail of the scan sits at the top; the keyboard has a **Done** button, and dragging the form dismisses it.
   Optionally fix the merchant capitalization. Try typing a bad total such as `abc` to see the validation message.
6. **Save.** The receipt appears in history, newest first, with merchant, date and amount.
7. **Open it** to see the saved fields and the raw text. Swipe left on a row (or use **Delete receipt** in the detail) to delete.
8. **Relaunch the app.** The receipt is still there: it is stored on the device with SwiftData.
9. **Discard path.** Scan again and tap **Discard**: nothing is added.

## What the demo shows

| Claim | Where to see it |
|-------|-----------------|
| OCR and parsing run on the device | Airplane mode: the flow works the same |
| Uncertainty is surfaced, not guessed | Missing currency is flagged in Review |
| The user stays in control | Every field is editable; Save validates |
| History is persistent | Relaunch |
| The image is not stored | See [privacy-and-storage.md](privacy-and-storage.md) |

## Automated version

`swift test --filter EndToEndFlowTests` runs the same path on macOS with real Vision OCR: render a receipt,
scan, correct the draft, save to SwiftData, read it back in a new container (the relaunch), delete it.
The camera is the only piece it replaces.

`xcodebuild test -project ReceiptScanner.xcodeproj -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ReceiptScannerUITests`
drives the real UI in the simulator through the same script (sample receipt, Done button, currency menu, save, detail,
delete). Set `TEST_RUNNER_SHOT_DIR=<dir>` to also write a screenshot of each step.

## Not shown (known gaps)

- Scanning a real receipt with the camera was not run in the simulator (there is no camera); it needs a device.
- Device timing and memory numbers are not collected yet; see [performance.md](performance.md).
