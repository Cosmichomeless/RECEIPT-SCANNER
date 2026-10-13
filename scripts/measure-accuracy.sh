#!/bin/bash
# Measures parser accuracy over a folder of real tickets.
#
#   scripts/measure-accuracy.sh <folder> [report.md]
#
# The folder holds pairs: `ticket1.txt` (the OCR text of the ticket) and `ticket1.json` (what a careful
# reader sees). The JSON has the same fields as the files in Tests/ReceiptKitTests/Fixtures:
#
#   { "locale": "es_ES", "merchant": "MERCADONA", "date": "2026-10-06", "total": "12.34",
#     "currency": "EUR", "issues": [], "taxBase": "11.22", "taxRate": "10", "taxAmount": "1.12",
#     "taxID": "A46103834" }
#
# `issues` lists what the app should ask the user about (missingDate, missingCurrency, ...).
# `taxBase`/`taxRate`/`taxAmount` and `taxID` are optional. Pairs may also sit in sub-folders.
# `scripts/ocr-tickets.sh` makes the pairs from photos of tickets.
# Prints per-field accuracy overall, by locale and by category, and every miss.
# Tickets contain personal data: keep the folder out of the repository.
set -euo pipefail

if [ $# -lt 1 ]; then
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
  exit 64
fi

cd "$(dirname "$0")/.."
export RECEIPT_FIXTURES_DIR="$1"
[ $# -ge 2 ] && export RECEIPT_REPORT_FILE="$2"
swift test --filter "QualityReportTests/measuresExternalTickets" 2>&1 | grep -v "^\[\|Test run\|Test case\|started\|passed after\|^􀟈\|^􁁛"
