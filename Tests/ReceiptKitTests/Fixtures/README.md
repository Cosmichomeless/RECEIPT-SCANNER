# Receipt fixtures

Each fixture is a pair of files in a category folder:

- `name.txt`: the OCR text of a receipt, as Vision would return it (one line per row).
- `name.json`: what a careful reader would extract. This is ground truth, not what the parser currently outputs.

```json
{
  "locale": "es_ES",
  "merchant": "CAFE LUNA",
  "date": "2026-10-06",
  "total": "5.50",
  "currency": "EUR",
  "issues": ["missingCurrency"]
}
```

`null` means the field cannot be read from the text and the parser must not invent it. `issues` lists the
kinds the parser should report: `missingMerchant`, `missingDate`, `ambiguousDate`, `missingTotal`,
`missingCurrency`, `ambiguousCurrency`.

Categories: `supermarket`, `restaurant`, `fuel-station`, `hardware-store`, `malformed`.
To add a case, drop a new pair in a category. `FixtureRegressionTests` picks it up automatically.
