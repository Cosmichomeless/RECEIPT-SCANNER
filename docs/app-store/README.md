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
3. **Signing.** Set a development team for the `ReceiptScanner` target (bundle id `dev.cosmichomeless.ReceiptScanner`,
   iPhone only, iOS 17+). `project.yml` has no team yet; add `DEVELOPMENT_TEAM` there and run `xcodegen generate`.
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
