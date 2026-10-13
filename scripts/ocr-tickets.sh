#!/bin/bash
# Reads photos of tickets with the app's own OCR and drafts the files scripts/measure-accuracy.sh needs.
#
#   scripts/ocr-tickets.sh <photos folder> <output folder> [locale, default es_ES]
#
# For every photo (jpg, png, heic, tiff) it writes `name.txt` (the recognized text) and a draft
# `name.json` with what the parser reads. Open each JSON next to the paper ticket and CORRECT it:
# merchant, date (yyyy-mm-dd), total, currency (EUR, USD...), and `issues` (what the app should ask
# the user, for example "missingCurrency"). Add taxBase/taxRate/taxAmount/taxID when the ticket shows them.
# An uncorrected draft only proves that the parser agrees with itself.
# Tickets contain personal data: keep both folders out of the repository.
set -euo pipefail

if [ $# -lt 2 ]; then
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 64
fi

cd "$(dirname "$0")/.."
export RECEIPT_IMAGES_DIR="$1"
export RECEIPT_FIXTURES_DIR="$2"
export RECEIPT_LOCALE="${3:-es_ES}"
swift test --filter "QualityReportTests/draftsExpectedFilesFromTicketPhotos" 2>&1 | grep -E "^(Wrote|Skipped)|error|recorded an issue|failed"
