# Compliance answers

Based on the code at version 1.1.0: no network use, no analytics or third-party SDKs, no account, no tracking.
If any of that changes (for example iCloud sync, issue #48), revisit this file first.

## App information

| Field | Value |
| --- | --- |
| Name | Receipt Scanner Offline (the home-screen name, `CFBundleDisplayName`, stays "Receipt Scanner") |
| Bundle ID | `dev.cosmichomeless.ReceiptScanner` |
| SKU | `receipt-scanner-ios` |
| Primary category | Finance |
| Secondary category | Productivity |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait, iOS 17.0+ |
| Primary language | English (U.S.); localized into es, fr, de |
| Price | Free (USD 0.00 price point, no in-app purchases) |

## App Privacy ("nutrition label")

- **Do you or your third-party partners collect data from this app?** No.
- Result: **Data Not Collected**. Receipts are processed on the device (Vision) and stored locally (SwiftData);
  nothing is transmitted to the developer or any third party.
- Tracking: **No**. The app does not track users (`NSPrivacyTracking = false`, no tracking domains).
- Privacy manifest: `ReceiptScanner/PrivacyInfo.xcprivacy` declares no collected data types and no required-reason
  APIs. The code uses none (no `UserDefaults`, file timestamp, disk space, boot time or active keyboard APIs; checked
  with a source search).

## Age rating

Answer **None** / **No** to every content question (no violence, sexual content, profanity, gambling, horror,
medical information, alcohol/tobacco/drugs, contests, unrestricted web access, user-generated content or chat).
Expected rating: **4+**.

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is set in the Info.plist. The app uses no encryption beyond what the
operating system provides, so no export compliance documents are needed.

## EU Digital Services Act (trader status)

This is a declaration only the account holder can make. Choose **trader** if the app is offered as part of a
trade, business or profession (including a paid app or one that promotes a business), otherwise **non-trader**.
A trader must provide a contact address, phone number and email, which Apple shows on the EU product page.
Without a declaration the app is not distributed in the EU.

## Permissions

| Key | Text shown to the user |
| --- | --- |
| `NSCameraUsageDescription` | Receipt Scanner uses the camera to scan paper receipts. Images are processed on your device and never uploaded. |

The string is localized in `ReceiptScanner/Resources/InfoPlist.xcstrings`.

## App Review notes

> Receipt Scanner scans paper receipts with the system document camera and reads them on the device. It has no
> account, no sign-in, no network use and no in-app purchases, so no demo credentials are needed.
>
> The scan feature requires a physical iPhone with a camera. If you review on a device and have no paper receipt, any
> printed receipt with a visible total works. History, review, detail and export (CSV and PDF, via the share sheet)
> work without a network connection.
>
> The first tap on Scan shows the standard camera permission prompt. Declining shows a message explaining that the
> camera is unavailable; the app does not crash.

## Content rights and advertising identifier

- Uses third-party content: **No**.
- Uses the Advertising Identifier (IDFA): **No**.
