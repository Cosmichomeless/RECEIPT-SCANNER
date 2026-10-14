# Device testing checklist (issue #37)

What has to be checked on a physical iPhone before the App Store build. The simulator has no camera and a
Mac has far more memory than a phone, so none of this can be replaced by `swift test`.

Use a **Release** or TestFlight build (Debug adds overhead and shows the sample-receipt action). Test on the
oldest and smallest iPhone you own as well as the newest one if you have both. Write the results in the
table at the end and copy the numbers into [performance.md](performance.md#device-measurements).

## What the code already does for memory (reviewed, not measured)

- A capture is a `CGImage` of about 12 MP (3024x4032, roughly 48 MB decoded). Vision reads a copy downscaled
  to 2400 px on the longest side (about 22 MB), and that copy is released once recognition ends.
- After recognition, `ScanFlow` keeps only a **1200 px** image for the review thumbnail
  (`ScanFlow.reviewImageMaxDimension`, about 4 MB). The full capture is released as soon as the scan is
  processed, so memory does not stay high while the user edits the form.
- Scanned images are never saved: only the parsed fields reach SwiftData.
- Only one capture is processed at a time: outcomes that arrive while a scan is `.processing` are ignored,
  so the document camera cannot start two recognitions on top of each other.
- Multi-page documents: only the first page is read (see `DocumentScannerView`).
- History, detail and export handle small text records, not images. Export runs off the main thread.

What is **not** known without a device: real OCR time on small thermal print, peak memory on an iPhone with
3-4 GB of RAM, battery and heat after many scans in a row.

## 1. Setup

- [ ] Install the Release/TestFlight build. Airplane mode on for the whole test (the app must not need the
  network).
- [ ] Open the app once with Xcode's Memory gauge (Debug navigator) or Instruments > Allocations attached, if
  you can. If not, just watch for crashes and slowness.

## 2. Camera and permission

- [ ] First launch: tapping Scan shows the system camera prompt with the text from `NSCameraUsageDescription`
  (in the phone's language).
- [ ] Deny it: the app shows the "camera unavailable" message, no crash. Settings > ReceiptScanner > Camera
  re-enables it and the next scan works.
- [ ] Cancel the document camera without taking a photo: back to the home screen, nothing saved.

## 3. Real tickets (also feeds #38)

Scan at least 10 tickets: supermarket, restaurant, fuel, pharmacy, a crumpled one, a faded thermal one, a
long one that needs several shots, and one in a language other than your phone's.

For each ticket note: did the merchant, date, total and currency come out right? Did the app ask about
anything it should not have (or fail to ask)? Then in **Review > Diagnostics** write down image size, text
recognition time and parsing time.

- [ ] Recognition time is below about 2 s per ticket on your oldest phone (the Mac measures ~0.1 s on clean
  synthetic pages; real print is slower). If it is much slower, say so in the issue.
- [ ] Faded or small print is read. If characters are lost, raise `maxPixelDimension` in
  `VisionOCRService.init` (now 2400) and measure again.
- [ ] Bulk measurement: copy the photos to a Mac and use `scripts/ocr-tickets.sh` and
  `scripts/measure-accuracy.sh` (see [performance.md](performance.md#measuring-real-tickets)).

## 4. Memory and stability

- [ ] Scan and save 20 tickets in a row without closing the app: no slowdown, no crash, no memory warning.
  With Instruments, memory returns close to its starting level between scans (a sawtooth, not a staircase).
- [ ] During review, with the thumbnail visible, memory is not higher than a few tens of MB above the idle
  baseline (the full-size capture must be gone).
- [ ] Take two quick captures: tap Save in the document camera twice, or scan again right away. Only one
  ticket is created.
- [ ] Put the app in the background in the middle of a scan (swipe home) and come back: it either finishes or
  returns to the home screen, never a frozen spinner.
- [ ] Receive a phone call or lock the screen during the document camera: no crash on return.
- [ ] Low Power Mode on: a scan still completes.
- [ ] Heat and battery: after 20 scans the phone is not unusually hot; note the battery used.

## 5. Whole flow

- [ ] Review: correct each field, change currency, save. Relaunch: the receipt is in History with the values
  you saved.
- [ ] Open detail, delete a receipt, relaunch: it stays deleted.
- [ ] History with 100+ receipts (add many quickly with real scans or by re-saving): scrolling stays smooth.
- [ ] Export CSV and PDF: the share sheet opens and the file opens correctly in Files, Numbers or Preview. The
  Images format is absent (no scans are kept).
- [ ] Largest accessibility text size and dark appearance: nothing is cut off on the smallest iPhone.
- [ ] Spanish, French, German and English phone language: all text is translated and fits.
- [ ] The Debug-only "Try sample receipt" action is absent in the Release build.

## Results

| Device and iOS | Tickets | Avg recognition ms | Worst recognition ms | Peak memory MB | Problems |
|----------------|---------|--------------------|----------------------|----------------|----------|
|                |         |                    |                      |                |          |

When done, comment on issue #37 with the table and any problem found. Close #37 only when every box above is
ticked or explained.
