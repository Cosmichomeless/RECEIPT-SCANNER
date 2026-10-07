# Performance and accuracy

How fast the scan pipeline is, how accurate the parsers are, and what is still unmeasured.
Numbers come from `swift test` on an Apple-silicon Mac (debug build) unless stated otherwise.
Refresh them with:

```sh
swift test --filter QualityReportTests        # accuracy and parse time
swift test --filter OCRCostMeasurementTests   # OCR time by image size
```

## Parser accuracy (fixtures)

`QualityReportTests` runs every fixture in `Tests/ReceiptKitTests/Fixtures` (23 receipts across
supermarket, restaurant, fuel station, hardware store and malformed text) and compares each field with the
ground truth written by hand. A field below 95 % fails the suite.

| Field    | Correct | Accuracy |
|----------|---------|----------|
| merchant | 23/23   | 100 %    |
| date     | 23/23   | 100 %    |
| total    | 23/23   | 100 %    |
| currency | 23/23   | 100 %    |
| issues   | 23/23   | 100 %    |

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

## Device measurements

Not taken yet: the numbers above come from a Mac with synthetic images. To collect real ones, scan receipts on
a device and open **Review → Diagnostics**, which shows image size, text recognition time and parsing time
for the last scan. The same values are logged under subsystem `ReceiptKit`, category `processing`
(no receipt text is logged). Memory is not measured in code; use Xcode's Memory gauge or Instruments
(Allocations) during a scan. If real receipts lose characters at 2400 px, raise `maxPixelDimension` in
`VisionOCRService.init`.

## Known limitations

- **Real OCR noise is only partly covered.** Fixtures include digit/letter swaps in amounts (`8O.5O`) and
  split decimals (`3 . 25`), but not skewed photos, glare, crumpled paper or faded print.
- **Dates with OCR errors** (`O6/1O/2O26`) are reported as a missing date, not repaired.
- **Thousands separated by spaces** (`1 234,56`) are read as `1 234.56`, so the total can be wrong or missed.
- **Restaurant tips:** when the printed total excludes a handwritten tip, the parser returns the printed total.
- **Languages:** keywords exist for English and Spanish. German and French receipts parse only where the layout
  matches (currency codes, numbers), and usually need review.
- **A lone comma typed by hand** (`1,234`) is always read as a decimal mark in the review form.
- **Currency is never guessed:** a receipt with no symbol or code yields a `missingCurrency` issue even when
  the device locale suggests one; the locale only breaks ties between currencies that share a symbol (`$`).
- **Single receipt per image**, portrait orientation, one currency.
