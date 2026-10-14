# App Store Connect pack

Everything needed to fill in App Store Connect for **Receipt Scanner 1.1.0 (build 1)**, so it can be applied by hand
or by an automation (for example an App Store Connect MCP). Nothing here has been submitted.

## Order of operations

1. **Publish the support and privacy pages.** Repository Settings → Pages → Deploy from a branch → `main` → `/docs`.
   After a minute these should answer (open both before continuing):
   - Support URL: <https://cosmichomeless.github.io/RECEIPT-SCANNER/>
   - Privacy Policy URL: <https://cosmichomeless.github.io/RECEIPT-SCANNER/privacy/>
2. **Finish the device checks** in [../device-testing.md](../device-testing.md) (issues #37 and #38). These need a
   physical iPhone and real receipts and cannot be done by the repo.
3. **Signing.** `project.yml` pins `DEVELOPMENT_TEAM` for the `ReceiptScanner` target (bundle id
   `dev.cosmichomeless.ReceiptScanner`, iPhone only, iOS 17+). Run `xcodegen generate` after changing it.
4. **Tag and archive.** With CI green on the commit, tag `v1.1.0`, archive, upload to TestFlight (#47) and test the
   uploaded build.
5. **App Store Connect:** create the app record, then apply [listing text](#listing-text) and
   [compliance answers](compliance.md).
6. Submit for review only after the TestFlight build has been tested.

## Listing text

| Locale | File | Use for |
| --- | --- | --- |
| English (U.S.) | [en-US.md](en-US.md) | Primary language; also en-GB, en-AU, en-CA |
| Spanish (Spain) | [es-ES.md](es-ES.md) | es-ES and es-MX |
| French (France) | [fr-FR.md](fr-FR.md) | fr-FR and fr-CA |
| German | [de-DE.md](de-DE.md) | de-DE |

Each file lists name, subtitle, promotional text, keywords, description, what's new, support URL and privacy URL.
Length limits (name and subtitle 30, promotional text 170, keywords 100, description 4000) are respected.

## Not in this pack

- **Screenshots.** The localized screenshots with local receipt examples (issue #46) still have to be captured from
  the simulator or device in each language; `docs/screenshots/` holds English simulator captures only.
- **Pricing and territories.** Not decided in the repo.
- **Copyright holder and contact details** for App Store Connect.

The store name is **Receipt Scanner Offline**: "Receipt Scanner" and "Private Receipt Scanner" were taken by other apps.
It already contains "receipt", "scanner" and "offline", so the keyword lists do not repeat them. The icon label on the
home screen stays "Receipt Scanner" (`CFBundleDisplayName`). The Support URL is the site's home page, which has the FAQ
and the link to open an issue.

## Category, price and other fields

| Field | Proposal |
|-------|----------|
| Primary category | Finance |
| Secondary category | Productivity (or Business) |
| Price | Free, no in-app purchases (the goal is to launch without monetization) |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY: 1`); portrait |
| Version / build | 1.1.0 (1) |
| Content rights | Does not contain, show or access third-party content |
| Advertising identifier (IDFA) | No |

## Screenshot captions (value messages, not just screens)

Needed sizes: 6.9" (1320x2868) is mandatory; #47 also asks for 6.5". Capture them from the simulator named
"iPhone 17 Pro Max" with the demo data in [demo.md](../demo.md) (do not commit them). Repeat for each language (#46). Suggested order and captions:

| # | Screen | English caption | Español |
|---|--------|-----------------|---------|
| 1 | Scan | Scan any receipt in seconds | Escanea cualquier ticket en segundos |
| 2 | Review | Check every detail before you save | Revisa cada dato antes de guardar |
| 3 | Review with a highlighted field | It asks instead of guessing | Pregunta en vez de adivinar |
| 4 | VAT fields | VAT, base and tax ID, ready for your accountant | IVA, base y NIF, listos para tu gestor |
| 5 | Export | Export to CSV or PDF | Exporta a CSV o PDF |
| 6 | History | Private: everything stays on your iPhone | Privado: todo se queda en tu iPhone |

## Header and search-results artwork

The creative components of the product page ("Header" and "Search results" tabs in App Store Connect) are in
[assets/](assets/), one folder per language (`en`, `es`, `fr`, `de`). They are uploaded by hand with "Upload"; the
public API does not expose them.

| Folder | File | Size |
|--------|------|------|
| `assets/header/<lang>/` | `header-5244x2950.png`, `header-3840x1646.png` | 16:9 and wide banner |
| `assets/search/<lang>/` | `search-5244x2950.png` (same artwork as the header), `search-3840x2560.png`, `search-1920x1280.png` | 16:9 and 3:2 |

Blue background, app icon, "Receipt Scanner Offline", the localized tagline and two screenshots (Review and History).
