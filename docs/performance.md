# Performance and accuracy

How fast the scan pipeline is, how accurate the parsers are, and what is still unmeasured.
Numbers come from `swift test` on an Apple-silicon Mac (debug build) unless stated otherwise.
Refresh them with:

```sh
swift test --filter QualityReportTests        # accuracy and parse time
swift test --filter OCRCostMeasurementTests   # OCR time by image size
```

## Parser accuracy (fixtures)

`QualityReportTests` runs every fixture in `Tests/ReceiptKitTests/Fixtures` (89 receipts: 36 es_ES, 15 en_US,
13 de_DE, 12 fr_FR, 11 en_GB, 2 others; across supermarket, restaurant, fuel station, hardware store, pharmacy,
taxi and malformed text) and compares each field with the ground truth written by hand. A field below 95 % fails
the suite. `tax` and `taxID` only count the receipts whose expected file has those values (25 and 14).

The 28 original fixtures were all at 100 %. The 61 added for the release (German, French, English and Spanish
layouts: tax tables, savings lines, tips, month names, odd labels) were first run against the unchanged parsers:

| Field    | Before (89)   | After (89)   |
|----------|---------------|--------------|
| merchant | 88/89, 98.9 % | 89/89, 100 % |
| date     | 83/89, 93.3 % | 89/89, 100 % |
| total    | 81/89, 91.0 % | 89/89, 100 % |
| currency | 89/89, 100 %  | 89/89, 100 % |
| issues   | 76/89, 85.4 % | 89/89, 100 % |
| tax      | 23/25, 92.0 % | 25/25, 100 % |
| taxID    | 14/14, 100 %  | 14/14, 100 %  |

What changed in the parsers: totals that say they include tax (`TOTAL INCL VAT`) are no longer excluded as tax
lines; sums of savings (`TOTAL DESCUENTOS`, `TOTAL REMISES`, `RABATT`) are no longer totals; `BETRAG` and
`A PAYER` are total labels; German and French month names are read; digit look-alikes in keywords (`T0TAL`) are
repaired; `STATION TOTAL` is a merchant; 2.1 % VAT is a known rate. Each fix has a unit test.

To see the breakdown by locale and category, and every miss with what was read against what was expected, use
`scripts/measure-accuracy.sh Tests/ReceiptKitTests/Fixtures`.

### Measuring real tickets

```sh
scripts/ocr-tickets.sh <photos folder> <pairs folder> [es_ES]   # app's own OCR -> name.txt + draft name.json
# correct each name.json against the paper ticket (an uncorrected draft only measures the parser against itself)
scripts/measure-accuracy.sh <pairs folder> [report.md]          # per field, locale and category, plus misses
```

Both are plain `swift test` filters gated by environment variables, so they need no extra tooling. Keep the
folders outside the repository: tickets hold personal data. 100+ real tickets are the goal of issue #38.

"issues" counts a receipt as correct only when the parser reports exactly the problems a reader would
(for example `missingCurrency` for a receipt that prints no currency). Declining to guess counts as correct;
guessing wrong does not.

**Read this number carefully.** The fixtures were written while fixing the parsers, so 100 % means "no known
regressions", not "100 % of real receipts". Fixture text is clean OCR output; real Vision output adds
noise the fixtures only partly imitate (see limitations).

## Processing cost

| Stage                         | Before | After  | Change |
|-------------------------------|--------|--------|--------|
| Parsing, average per receipt  | 7.9 ms | 0.77 ms | ~10× faster |
| Parsing, worst fixture        | 37.8 ms | 9.0 ms | ~4× faster |

Cause: `String.range(of:options: .regularExpression)` recompiled its pattern for every line and every
keyword in `MerchantParser`, and `CurrencyParser` built two regexes per line. `RegexCache` now compiles each
pattern once. `QualityReportTests.parsingStaysCheap` fails if the average exceeds 5 ms or any receipt 50 ms.

Parsing is now negligible next to OCR, which dominates a scan.

### OCR by image size

`VisionOCRService` downscales captures whose longest side exceeds `maxPixelDimension` (default 2400 px)
before recognition. Measured on a synthetic 3024×4032 receipt page (macOS, accurate recognition, best of 3):

| Image      | OCR time | Total read | Decoded bitmap |
|------------|----------|------------|----------------|
| 3024×4032  | 127 ms   | yes        | 48.8 MB        |
| 2250×3000  | 117 ms   | yes        | 27.0 MB        |
| 1800×2400  | 119 ms   | yes        | 17.3 MB        |
| 1350×1800  | 111 ms   | yes        | 9.7 MB         |
| 900×1200   | 80 ms    | yes        | 4.3 MB         |
| 600×800    | 65 ms    | yes        | 1.9 MB         |

Findings:

- On this page, time barely changes between native size and 2400 px (about 7 %); the clear win is memory,
  because the bitmap Vision works on shrinks by about 65 %.
- The page uses large, clean type, so text stays readable even at 600×800. **Real receipts use small,
  faded thermal print**, so the safe cap is higher than this table suggests. 2400 px is a conservative
  choice, not a measured optimum.

## Memory (reviewed by code, not yet measured on a device)

A 12 MP capture is about 48 MB decoded, so the pipeline avoids holding it:

- `VisionOCRService` reads a copy downscaled to 2400 px (about 22 MB) that lives only during recognition.
- `ScanFlow` swaps the capture for a 1200 px image (`ScanFlow.reviewImageMaxDimension`, about 4 MB) as soon as
  the scan is processed. Before this change the full-size image stayed in memory for the whole review, because
  the `.review` state held it only to draw a thumbnail. `ScanFlowTests` check that OCR still sees the full
  size, that the review image is capped, and that small images are untouched.
- A second capture delivered while one is being processed is ignored, so two recognitions never overlap.
- Images are never persisted; SwiftData holds text fields only.

## Device measurements

Not taken yet: the numbers above come from a Mac with synthetic images. To collect real ones, scan receipts on
a device and open **Review → Diagnostics**, which shows image size, text recognition time and parsing time
for the last scan. The same values are logged under subsystem `ReceiptKit`, category `processing`
(no receipt text is logged). Memory is not measured in code; use Xcode's Memory gauge or Instruments
(Allocations) during a scan. If real receipts lose characters at 2400 px, raise `maxPixelDimension` in
`VisionOCRService.init`. The full list of things to check on the phone, with a results table, is in
[device-testing.md](device-testing.md).

## Known limitations

- **Real OCR noise is only partly covered.** Fixtures include digit/letter swaps in amounts (`8O.5O`) and
  split decimals (`3 . 25`), but not skewed photos, glare, crumpled paper or faded print.
- **Dates with OCR errors** (`O6/1O/2O26`) are reported as a missing date, not repaired.
- **Thousands separated by spaces** (`1 234,56`) are read as `1 234.56`, so the total can be wrong or missed.
- **Restaurant tips:** when the printed total excludes a handwritten tip, the parser returns the printed total.
- **Languages:** keywords exist for English, Spanish, German and French, tested on hand-written fixtures only.
  Italian, Portuguese and other languages parse only where the layout matches and usually need review.
- **A lone comma typed by hand** (`1,234`) is always read as a decimal mark in the review form.
- **Currency is never guessed:** a receipt with no symbol or code yields a `missingCurrency` issue even when
  the device locale suggests one; the locale only breaks ties between currencies that share a symbol (`$`).
- **Single receipt per image**, portrait orientation, one currency.
