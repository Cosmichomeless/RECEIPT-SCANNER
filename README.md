# Receipt Scanner

> Native iOS receipt scanner using on-device OCR, text normalization, and heuristic parsing.

## Overview

Receipt Scanner is a native iOS application capable of scanning purchase receipts and extracting structured information directly on the device.

The project is designed to explore Apple's Vision ecosystem, document scanning, OCR, text normalization, heuristic parsing, and processing imperfect real-world data.

The main challenge is not OCR itself.

The real engineering problem is transforming noisy and inconsistent OCR output into reliable structured information.

## Goals

The application will initially extract:

- Merchant
- Date
- Total amount
- Currency

The project is designed to demonstrate knowledge of:

- Swift
- SwiftUI
- Vision
- VisionKit
- AVFoundation
- On-device OCR
- Image processing
- Text normalization
- Heuristic algorithms
- Parsing
- SwiftData
- Swift Concurrency
- Automated testing

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Document Scanning:** VisionKit
- **OCR:** Vision
- **Camera:** AVFoundation when lower-level control is required
- **Persistence:** SwiftData
- **Concurrency:** Swift Concurrency
- **Testing:** Swift Testing / XCTest

The application should process receipts locally whenever possible.

No external OCR service is required for the initial version.

## Processing Pipeline

The core processing pipeline will be:

```text
Camera / Document Scanner
        ↓
      Image
        ↓
   Vision OCR
        ↓
    Raw Text
        ↓
Text Normalization
        ↓
 Receipt Parser
        ↓
Structured Receipt
        ↓
User Validation
        ↓
    SwiftData
```

OCR and parsing must remain independent components.

## MVP

The first version should support:

- Document scanning
- On-device OCR
- Raw text extraction
- Merchant detection
- Date detection
- Total detection
- Currency detection
- Manual correction
- Receipt persistence
- Receipt history

## Data Model

Initial model:

```text
Receipt
├── id
├── merchant
├── date
├── total
├── currency
├── rawText
├── createdAt
└── imagePath?
```

The original scanned image may optionally be retained depending on storage and privacy decisions.

## OCR Architecture

OCR should only be responsible for recognizing text.

```text
Receipt Image
      ↓
  OCRService
      ↓
  OCRResult
```

The parsing engine should then consume the result independently:

```text
OCRResult
      ↓
ReceiptParser
      ↓
ParsedReceipt
```

This separation allows parsing logic to be tested without requiring a camera or OCR execution.

## Parsing Strategy

Receipt formats vary significantly between businesses.

The parser will therefore combine several heuristics.

### Total Detection

Possible keywords include:

```text
TOTAL
GRAND TOTAL
AMOUNT
AMOUNT DUE
TOTAL EUR
TOTAL €
```

The parser must distinguish them from values such as:

```text
SUBTOTAL
TAX
VAT
DISCOUNT
CHANGE
```

Candidate totals may be scored using:

- Keyword proximity
- Position in the document
- Currency symbols
- Numeric format
- Relationship to subtotal and taxes

### Date Detection

The parser should initially support formats such as:

```text
06/10/2026
06-10-2026
2026-10-06
06 OCT 2026
06/10/26
```

Detected dates should be normalized internally.

### Merchant Detection

Merchant detection may analyze the first lines of the receipt while filtering:

- Addresses
- Telephone numbers
- Tax identifiers
- Postal codes
- URLs
- Numeric-only lines

A scoring system may be introduced as the parser evolves.

### Currency Detection

Currency may be inferred using:

- Currency symbols
- Currency codes
- Numeric formatting
- Receipt locale when available

## Example

OCR might produce:

```text
NORTHLINE HARDWARE
MARKET STREET

HEX KEY SET       18.99
WOOD GLUE          6.49

SUBTOTAL          76.92
TAX                7.45
TOTAL             84.37

VISA ****4471
```

The parser should produce something similar to:

```text
Merchant: Northline Hardware
Total: 84.37
Currency: EUR
```

## Testing Strategy

Parsing is one of the most important parts of the project and should have strong automated test coverage.

Test fixtures may include:

```text
Tests/
└── Fixtures/
    ├── supermarket/
    ├── restaurant/
    ├── fuel-station/
    ├── hardware-store/
    └── malformed/
```

Tests should cover:

- Different receipt layouts
- Different date formats
- Decimal separators
- Currency formats
- OCR mistakes
- Missing fields
- Multiple candidate totals
- Poorly formatted text

## Project Structure

Initial direction:

```text
ReceiptScanner/
├── App/
├── Features/
│   ├── Scanner/
│   ├── ReceiptReview/
│   └── ReceiptHistory/
├── OCR/
├── Parsing/
│   ├── MerchantParser/
│   ├── DateParser/
│   ├── TotalParser/
│   └── CurrencyParser/
├── Persistence/
├── Models/
└── Tests/
```

## Development Roadmap

### Phase 1 — Product Definition

Define:

- Product scope
- MVP
- Scanner flow
- Validation flow
- History flow

### Phase 2 — Architecture

Define:

- Scanner boundaries
- OCR service
- Parser architecture
- Persistence layer

### Phase 3 — Data Model

Design the receipt domain model and persistence strategy.

### Phase 4 — Document Scanner

Implement VisionKit scanning.

### Phase 5 — OCR

Implement on-device text recognition using Vision.

### Phase 6 — Text Normalization

Normalize:

- Whitespace
- Line breaks
- Decimal formats
- OCR artifacts

### Phase 7 — Total Parser

Build and test total detection heuristics.

### Phase 8 — Date Parser

Build and test date detection.

### Phase 9 — Merchant & Currency

Implement additional parsing heuristics.

### Phase 10 — Persistence

Store validated receipts locally.

### Phase 11 — Validation UI

Allow users to review and correct detected fields.

### Phase 12 — Test Dataset

Build a representative receipt fixture dataset.

### Phase 13 — Optimization

Improve:

- OCR latency
- Parser accuracy
- Memory usage

### Phase 14 — Documentation

Document:

- OCR architecture
- Parsing strategies
- Limitations
- Technical decisions

### Phase 15 — Release

Prepare final demo and release documentation.

## Out of Scope

The first version will not include:

- Accounts
- Cloud synchronization
- Bank integrations
- Budget management
- Expense analytics
- Generative AI
- External OCR APIs
- Collaborative receipts

## Project Philosophy

This project should not be presented simply as:

> An app that scans receipts.

The engineering focus is:

> A native on-device document processing pipeline that transforms imperfect OCR output into structured data using testable heuristic algorithms.

## Status

🚧 **In development**

Current stage:

**Phase 1 — Product Definition**
