# OCR pipeline and parsing trade-offs

How a photo of a receipt becomes a validated `Receipt`, which component owns each step, and what
the heuristics can and cannot do. Measurements are in [performance.md](performance.md); storage and
privacy decisions are in [privacy-and-storage.md](privacy-and-storage.md).

## Component boundaries

```text
VisionKit scanner ─▶ CGImage ─▶ VisionOCRService ─▶ OCRResult ─▶ TextNormalizer ─▶ NormalizedText
                                                                                        │
              ┌───────────────┬────────────────┬──────────────────┬──────────────────────┘
              ▼               ▼                ▼                  ▼
        MerchantParser   DateParser       TotalParser       CurrencyParser
              └───────────────┴──── DefaultReceiptParser ───┴──────┘
                                           │
                                     ParsedReceipt ─▶ ReceiptDraft (review UI) ─▶ Receipt ─▶ ReceiptRepository
```

| Component | Owns | Must not |
|-----------|------|----------|
| `ReceiptImageCapture` (VisionKit, app target) | Getting a `CGImage` or a cancel/failure outcome | Read text |
| `VisionOCRService` | Downscaling, running Vision, putting lines in reading order | Interpret text; only this file talks to Vision |
| `TextNormalizer` | Whitespace, line breaks, digit look-alikes (`8O.5O` → `80.50`), decimal formats (`1.234,56` → `1234.56`) | Decide what a number means |
| Field parsers | One field each, from `NormalizedText` | Touch images, UI or storage; they are pure and synchronous |
| `DefaultReceiptParser` | Running the four parsers and turning gaps into `ParsingIssue`s | Guess a missing field |
| `ReceiptDraft` + `ReviewView` | The user's corrections; `canSave` only when merchant and total are valid | Change parser output silently |
| `ReceiptRepository` | Storing validated `Receipt` values (SwiftData or in memory) | Know about OCR |
| `ReceiptProcessor` / `ScanFlow` | Composing the stages and the screen state machine | Contain heuristics |

Two rules keep this testable: OCR never interprets, and parsers never see an image. Because of that, every
heuristic runs under `swift test` on macOS with plain text (`OCRResult(text:)`), without a camera or device.

## Heuristics

All parsers score candidates and accept one only above a threshold. Below it the field stays empty and
becomes a `ParsingIssue`, which the review screen shows as something to fill in.

**Total** (`TotalParser`). Every amount on the page is a candidate.
- Label: `GRAND TOTAL`, `AMOUNT DUE`, `TOTAL A PAGAR`… score highest; bare `TOTAL`/`IMPORTE` next; an amount
  alone under a keyword line gets a smaller bonus. `SUBTOTAL`, tax, discount, change, cash, tip are excluded
  first, so `TOTAL TAX` is never a total.
- Position: the lower half of the receipt, but not the very last lines (card slips, URLs).
- Relationship: if a subtotal is present, a candidate equal to `subtotal − discount + tax` is boosted and one
  below `subtotal − discount` is penalized.
- Acceptance needs keyword evidence; a lone number is never returned.

**Date** (`DateParser`). Numeric (`06/10/2026`, `06.10.26`), ISO and month-name formats in English and
Spanish. A line labelled `DATE`/`FECHA` outranks other dates. Day-first or month-first comes from the
locale; if the same text yields two different dates (`06/10/2026` could be 6 Oct or 10 Jun) the result is
`ambiguousDate` with both candidates, not a pick.

**Merchant** (`MerchantParser`). Scores the first eight non-empty lines by position and share of letters.
Lines that look like URLs, emails, phones, postal codes, dates, times, amounts, tax IDs, addresses or
boilerplate (`RECEIPT`, `THANK YOU`) are rejected. Words such as `PLAZA` or `ST` only mark an address when a
number is on the line, so `Café de la Plaza` stays a name.

**Currency** (`CurrencyParser`). ISO codes win, then unambiguous symbols (`€`, `£`), then shared symbols
(`$`, `¥`, `kr`). A shared symbol is narrowed by the device locale only if the locale's currency is one of
the candidates, then by the decimal separator seen in the original text. Otherwise the result is
`ambiguousCurrency` or `missingCurrency`.

## Trade-offs

| Decision | Chosen | Alternative and why not |
|----------|--------|-------------------------|
| Unknown values | Leave empty, ask the user | Guess from locale: a wrong currency saved silently is worse than one extra tap |
| Interpretation | Hand-written scoring | An ML/LLM model: opaque, hard to test, external or heavy; out of scope for the MVP |
| Vision language correction | Off | On: rewrites codes and abbreviations (`TOT` → `TOY`) |
| Recognition level | `.accurate` | `.fast`: receipts are small dense type; accuracy matters more than 100 ms |
| Ground truth for fixtures | What a careful reader would extract | Current parser output: would freeze its bugs as "expected" |
| Money type | `Decimal` | `Double`: rounding errors |
| Large captures | Downscale to 2400 px | Full resolution: ~65 % more bitmap memory for little time or accuracy gain on the Mac test |
| Every field editable | Yes | Trusting the parser: even at 100 % on fixtures, real accuracy is unknown |

## Accuracy limits

- Fixture accuracy is 100 % (23 receipts) but fixtures are clean text written with the parsers. It shows there
  are no known regressions, not real-world accuracy. See [performance.md](performance.md) for how to read it.
- Not covered: skewed or crumpled paper, glare, faded thermal print, multiple receipts in one photo.
- Known wrong or missing cases: space-grouped thousands (`1 234,56`), OCR errors inside dates (reported
  as a missing date), tips added by hand, German and French keywords.
- Anything the parser cannot read ends up in `ParsingIssue`, so the failure mode is "ask the user", not
  "save the wrong number".

## Extending

1. Add a fixture pair under `Tests/ReceiptKitTests/Fixtures/<category>/` with ground truth.
2. Run `swift test --filter FixtureRegressionTests`; a failure shows which field disagreed.
3. Fix the heuristic and add a focused unit test next to the parser's other tests.
4. Check `swift test --filter QualityReportTests` for accuracy and parse time.
