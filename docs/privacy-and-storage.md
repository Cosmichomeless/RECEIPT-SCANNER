# Data model, privacy and image retention

## Domain model

`Receipt` (value type, used by UI and logic) is stored as `ReceiptEntity`
(SwiftData `@Model`, persistence layer only). Mapping is `ReceiptEntity(receipt)` and
`entity.receipt`.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Unique. Never changes. |
| `merchant` | `String` | Required to save; the UI offers "Unknown merchant" when empty. |
| `date` | `Date?` | Optional. Stored at noon local time so the printed day does not shift. |
| `total` | `Decimal` | Never `Double`, to avoid rounding errors in money. |
| `currencyCode` | `String` | ISO 4217, for example `EUR`. |
| `rawText` | `String` | Original OCR text, kept for traceability and re-parsing. |
| `createdAt` | `Date` | Set once. |
| `imagePath` | `String?` | Relative path of the retained scan, `nil` when not kept. |

SwiftData keeps entities out of the rest of the app because `@Model` classes are not
`Sendable` and are bound to a `ModelContext`.

## Image retention policy

**Decision: the scanned image is not kept.**

**Current status: images are never written to disk.** `Receipt.imagePath` exists in the model and in
`ReceiptEntity` but is always `nil`; no code saves, reads or deletes image files yet.

- Receipts can contain card fragments, names and purchase habits. The structured fields
  and raw text are all the MVP needs for history.
- The image lives only in memory while scanning and reviewing (`ScanFlow.State.review` holds it) and is
  released when the receipt is saved or discarded. Large captures are downscaled to 2400 px before OCR.
- Nothing is uploaded: receipt processing has no network use, Vision runs on device, and there is no
  analytics or crash-reporting SDK.
- Timing logs (`ReceiptKit` subsystem) contain image size and durations only, never receipt text.
- `rawText` is stored because the user validated it; it can include sensitive lines such as
  `VISA ****4471`. This is a known trade-off: it is kept for traceability and re-parsing, and deleting a receipt
  from history removes it. A future option could mask card-like numbers before saving.

### If keeping images is added later (not implemented)

`ImageRetention.keep` is reserved for an explicit per-scan opt-in. The intended design: write inside the app
container (Application Support) with complete file protection, exclude it from iCloud and device backups,
store a path relative to that folder in `imagePath`, and delete the file when the receipt is deleted.
Until then `ImageRetention.default` (`.discard`) is the only behavior.
