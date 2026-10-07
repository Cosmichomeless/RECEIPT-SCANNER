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

**Decision: the scanned image is not kept by default.**

- Receipts can contain card fragments, names and purchase habits. The structured fields
  and raw text are all the MVP needs for history.
- By default the image lives only in memory during scanning and review and is discarded
  on save or discard (`ImageRetention.discard`).
- If the user opts in (`ImageRetention.keep`), the image is written inside the app's own
  container (Application Support), with complete file protection, excluded from
  iCloud/device backups. `imagePath` is relative to that folder.
- Deleting a receipt also deletes its image file.
- Nothing is ever uploaded: there is no network use in receipt processing.
- `rawText` is stored because the user has validated it; it can include sensitive lines
  such as `VISA ****4471`. This is a known trade-off, documented in the pipeline docs.
