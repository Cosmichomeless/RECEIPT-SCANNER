# RECEIPT SCANNER

## Project Overview

Receipt Scanner is a mobile application capable of scanning purchase receipts using the phone camera and extracting useful information directly on the device.

The application must work without requiring a remote OCR server.

The primary technical goal is to explore:

- Camera processing.
- OCR.
- On-device machine learning.
- Real-world text parsing.
- Local persistence.
- Mobile performance.

The project should focus on extracting structured information from messy real-world receipt data.

---

# Main Goal

The application should allow the user to point the camera at a receipt and automatically detect:

- Merchant.
- Date.
- Total amount.
- Currency.

Example:

Receipt detected

Merchant:
Northline Hardware

Date:
04 OCT 2026

Total:
84.37 €

The user should then be able to confirm or correct the detected information before saving it.

---

# Key Principle

OCR is NOT the main challenge.

The real challenge is:

OCR TEXT
    ↓
MESSY RECEIPT DATA
    ↓
PARSING
    ↓
STRUCTURED DATA

For example, a receipt may contain:

Subtotal: 76.92
Tax: 7.45
Total: 84.37

The system must understand that:

84.37

is the final total.

---

# Technology Stack

## Mobile

- React Native
- Expo
- TypeScript

A development build may be required because of native camera / ML dependencies.

## Camera

- React Native VisionCamera

## OCR

- Google ML Kit Text Recognition

## Local Storage

- MMKV

SQLite may be considered later if the data model becomes more complex.

## Styling

- NativeWind

---

# Main Technical Areas

The project should demonstrate:

- Camera permissions.
- Camera lifecycle.
- Frame processing.
- Image analysis.
- OCR.
- Text normalization.
- Pattern recognition.
- Regex.
- Heuristics.
- Parsing unstructured data.
- Local storage.
- Error handling.

---

# Application Flow

User opens scanner

    ↓

Camera preview

    ↓

Receipt detected

    ↓

Capture frame

    ↓

OCR

    ↓

Raw text

    ↓

Parser

    ↓

Merchant
Date
Total
Currency

    ↓

User confirmation

    ↓

Save locally

---

# Functional Requirements

## Scanner

The user must be able to:

- Open the camera.
- Position a receipt.
- Capture the receipt.
- Run OCR locally.
- View detected fields.

---

# OCR Output

Example OCR:

NORTHLINE HARDWARE
MARKET ST
PORTLAND OR

HEX KEY SET 9PC   18.99
WOOD GLUE 8OZ      6.49
SANDPAPER          9.96

SUBTOTAL           76.92
TAX                 7.45
TOTAL              84.37

VISA ****4471

The parser should transform this into:

Receipt {
    merchant: "Northline Hardware"
    date: ...
    total: 84.37
    currency: "EUR"
}

---

# Parsing Strategy

The parser should use multiple heuristics.

## Total Detection

Look for keywords such as:

- TOTAL
- GRAND TOTAL
- AMOUNT
- AMOUNT DUE
- TOTAL EUR
- TOTAL €

Avoid confusing them with:

- SUBTOTAL
- TAX
- CHANGE
- DISCOUNT

---

## Date Detection

Possible formats:

DD/MM/YYYY
DD-MM-YYYY
YYYY-MM-DD
04 OCT 2026
04/10/26

The parser should normalize them to one internal format.

---

## Merchant Detection

Possible strategy:

- Analyze first lines.
- Ignore addresses.
- Ignore phone numbers.
- Ignore tax identifiers.
- Score candidate lines.

Merchant detection will intentionally be heuristic rather than perfect.

---

# Data Model

Example:

Receipt {
    id
    merchant
    date
    total
    currency
    rawText
    createdAt
    imageUri?
}

---

# Receipt Library

The user should be able to view previous scans.

Example:

Northline Hardware
84.37 €
04 Oct 2026

Mercadona
37.54 €
03 Oct 2026

Amazon
22.99 €
01 Oct 2026

---

# Architecture

Suggested structure:

src/

features/
    scanner/
    receipts/

services/
    camera/
    ocr/
    parser/

services/parser/
    merchantParser.ts
    dateParser.ts
    totalParser.ts
    currencyParser.ts

storage/

components/

types/

utils/

---

# Important Engineering Principle

OCR and parsing must remain separate.

BAD:

Camera → OCR → UI

BETTER:

Camera
    ↓
OCR Service
    ↓
Raw OCR Result
    ↓
Receipt Parser
    ↓
Structured Receipt
    ↓
UI

This allows the parser to be tested independently from the camera.

---

# MVP

Initial MVP:

- Camera access.
- Capture receipt.
- OCR.
- Extract raw text.
- Detect total.
- Detect date.
- Detect merchant.
- User correction screen.
- Save receipt.
- Receipt history.

---

# Features Outside Initial MVP

Do NOT implement initially:

- Accounts.
- Cloud synchronization.
- Bank integration.
- Expense analytics.
- AI categorization.
- Automatic budgeting.
- Shared receipts.
- Remote OCR API.
- Complex accounting features.

---

# Testing Strategy

The parser should have strong automated tests.

Example fixtures:

receipts/
    supermarket.txt
    restaurant.txt
    hardware-store.txt
    fuel-station.txt

Tests should verify:

- Correct total.
- Correct date.
- Correct merchant.

The parsing engine is one of the most important parts of the project.

---

# Development Phases

## Phase 1 — Product Definition

Define:

- Scanner UX.
- Receipt result screen.
- Receipt library.

## Phase 2 — Camera

Implement:

- Permissions.
- Camera preview.
- Capture.

## Phase 3 — OCR

Integrate:

- ML Kit.
- Raw text extraction.

## Phase 4 — Parser

Implement:

- Amount detection.
- Date detection.
- Merchant detection.
- Currency detection.

## Phase 5 — Persistence

Implement local receipt library.

## Phase 6 — UX Improvements

Add:

- Highlight detected areas.
- Edit detected values.
- Error states.

## Phase 7 — Testing

Build parsing dataset and automated tests.

## Phase 8 — Documentation

Document:

- OCR pipeline.
- Parsing strategy.
- Technical decisions.
- Known limitations.

---

# Portfolio Value

The important part of this project is not that it scans receipts.

It should demonstrate:

- Computer vision integration.
- On-device processing.
- OCR.
- Parsing.
- Heuristic algorithms.
- Real-world data handling.
- Testing of imperfect data.
- React Native native-module integration.
