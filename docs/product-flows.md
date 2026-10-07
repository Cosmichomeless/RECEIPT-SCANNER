# Product definition: scanning, review and history flows

Closes the product scope for the MVP described in the README.

## MVP scope

A user scans a paper receipt, the app extracts merchant, date, total and currency
**on the device**, the user reviews and corrects those fields, and the receipt is
saved to a local history.

```text
Scan → OCR → Parse → Review / Correct → Save → History
```

## Screens

| # | Screen | Purpose |
|---|--------|---------|
| 1 | **History** (home) | Lists saved receipts, newest first. Entry point to scanning. Empty state invites the first scan. |
| 2 | **Scanner** | Full-screen VisionKit document camera. Cancel returns to History. |
| 3 | **Processing** | Short progress state while OCR and parsing run. Failure shows a retry / cancel choice. |
| 4 | **Review** | Shows the scanned image thumbnail plus editable merchant, date, total and currency. Fields the parser could not resolve are highlighted as "needs review". Save / Discard. |
| 5 | **Receipt detail** | Reopens a saved receipt: fields, raw OCR text, optional image. Fields can be edited again. |

## Flows

### Scan flow

1. User taps **Scan** on History.
2. Scanner presents the VisionKit camera. User captures one receipt page.
3. If the user cancels, return to History, nothing is stored.
4. If the scanner fails, show an error and offer to retry.
5. The captured image is handed to the OCR pipeline (Processing screen).

### Review flow

1. OCR returns raw text; the parser returns a `ParsedReceipt`.
2. Review shows every field with the parser's value, or empty when unknown.
3. Uncertain results (ambiguous date, no currency evidence, no total candidate) are
   never invented: the field is left empty and flagged for review.
4. The user can correct any field and fill missing ones.
5. **Save** is enabled once the receipt is valid (see below). **Discard** returns to
   History without storing anything.

A receipt is valid to save when it has a total amount and a currency. Merchant and
date may be left empty; the history shows them as "Unknown merchant" / no date.

### History flow

1. History lists saved receipts (merchant, date, total + currency).
2. Tapping a row opens the detail screen; edits are persisted.
3. Swipe to delete removes the receipt and any stored image.
4. The list is read from the local store, so it survives app restarts.

## Processing guarantees

- **On-device only.** Scanning, OCR and parsing run locally. No network access is
  needed or used for receipt processing.
- **No external OCR APIs.** OCR is Apple's Vision framework.
- OCR and parsing remain independent components so the parser can be tested without
  a camera or OCR execution.

## Out of scope for the first version

Confirmed exclusions, as stated in the README:

- Accounts
- Cloud synchronization
- Bank integrations
- Budget management
- Expense analytics
- Generative AI
- External OCR APIs
- Collaborative receipts

Also deliberately not in the MVP: multi-page receipts, line-item extraction, export,
and importing images from the photo library.
