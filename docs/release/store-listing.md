# App Store listing text (English and Spanish)

Ready to paste into App Store Connect. Nothing here has been entered for you. Limits: name 30, subtitle 30,
promotional text 170, keywords 100, description 4000. The counts were checked when this file was written.

The positioning follows issue #47: a private receipt scanner for self-employed people, with VAT as the hook.
The keywords below are educated guesses, not research. Validate them (search volume and competition, for example
with `keyword_insights` and `competitor_snapshot` from asc) before submitting.

## English (U.S.), primary language

| Field | Text | Chars |
|-------|------|-------|
| Name | Receipt Scanner | 15 |
| Subtitle | Private receipt & VAT scanner | 29 |
| Keywords | scan,expense,tracker,invoice,tax,ocr,csv,pdf,offline,freelance,accountant,bill,purchase,tickets,cash | 100 |
| Support URL | https://github.com/Cosmichomeless/RECEIPT-SCANNER/blob/main/docs/support.md | |
| Privacy policy URL | https://github.com/Cosmichomeless/RECEIPT-SCANNER/blob/main/docs/privacy.md | |
| Marketing URL (optional) | https://github.com/Cosmichomeless/RECEIPT-SCANNER | |
| Copyright | 2026 (your name) | |

If "Receipt Scanner" is already taken when you create the app record, App Store Connect says so. Fallbacks,
all within 30 characters: `Receipt Scanner Private`, `Receipt Scanner: VAT`, `Private Receipt Scanner`. The name on
the home screen stays "Receipt Scanner" whatever you choose (`CFBundleDisplayName`).

**Promotional text** (170, can be changed later without a new version):

```
Scan paper receipts, check the details and keep a history. Everything stays on your iPhone. No account, no ads, no tracking.
```

**Description:**

```
Receipt Scanner turns paper receipts into tidy records and keeps them on your iPhone. No account, no cloud, no ads.

Point the camera at a receipt and the app reads it on your device: merchant, date, total and currency, plus the VAT details when the receipt prints them (tax base, rate, amount and the merchant's tax ID). You check the result, fix anything that is wrong and save it.

WHY IT IS DIFFERENT
• Private by design. Text recognition runs on your iPhone with Apple's Vision framework. Nothing is uploaded, and there is no account, no analytics and no tracking.
• Honest about doubt. If a date can be read two ways, the currency is unclear or no total is found, the app leaves the field empty and asks you instead of guessing.
• Works offline, even in airplane mode.

WHAT YOU CAN DO
• Scan with the document camera, which finds the edges of the receipt for you.
• Review and edit merchant, date, total, currency, tax ID, tax base, VAT rate and VAT amount before saving.
• Keep a history of your receipts on your device.
• Export receipts as CSV (opens in Excel and Numbers) or as a printable PDF with totals per currency, for the dates you choose. Handy for your accountant or an expense report.
• Read receipts in English, Spanish, German and French. The app is available in the same four languages.
• Dark appearance and large text sizes are supported.

GOOD TO KNOW
• Receipt Scanner reads printed receipts. Results depend on the photo and the print quality, so always check the details before saving.
• The photo of the receipt is not kept. Only the extracted text and fields are stored, on your device.
• The app does not give tax or accounting advice.

Questions or problems: https://github.com/Cosmichomeless/RECEIPT-SCANNER/blob/main/docs/support.md
```

**What's New (1.0.0):**

```
First release.
```

## Español (España), localización adicional

| Campo | Texto | Caracteres |
|-------|-------|------------|
| Nombre | Receipt Scanner | 15 |
| Subtítulo | Tickets e IVA, todo privado | 27 |
| Palabras clave | recibo,factura,gastos,ocr,autónomo,escáner,cámara,csv,pdf,offline,privado,gestor,contabilidad,nota | 98 |
| URL de soporte | https://github.com/Cosmichomeless/RECEIPT-SCANNER/blob/main/docs/support.md | |
| URL de política de privacidad | https://github.com/Cosmichomeless/RECEIPT-SCANNER/blob/main/docs/privacy.md | |

La política de privacidad ya incluye la versión en español en la misma página. App Store indexa las palabras
clave de cada idioma por separado, así que no hace falta repetir "receipt" en la lista en español. No repitas
palabras que ya están en el nombre o el subtítulo (por eso no aparecen "receipt" ni "iva"): no suman.

**Texto promocional** (170):

```
Escanea tickets en papel, revisa los datos y guarda un historial. Todo se queda en tu iPhone. Sin cuenta, sin anuncios y sin rastreo.
```

**Descripción:**

```
Receipt Scanner convierte tickets en papel en registros ordenados y los guarda en tu iPhone. Sin cuenta, sin nube, sin anuncios.

Apunta la cámara a un ticket y la app lo lee en tu dispositivo: comercio, fecha, total y divisa, además de los datos del IVA cuando el ticket los imprime (base imponible, tipo, cuota y NIF del comercio). Tú compruebas el resultado, corriges lo que esté mal y lo guardas.

POR QUÉ ES DISTINTA
• Privada por diseño. El reconocimiento de texto se hace en tu iPhone con el framework Vision de Apple. No se sube nada y no hay cuenta, ni analíticas, ni rastreo.
• Sincera ante la duda. Si una fecha admite dos lecturas, la divisa no está clara o no se encuentra el total, la app deja el campo vacío y te pregunta en vez de adivinar.
• Funciona sin conexión, incluso en modo avión.

QUÉ PUEDES HACER
• Escanear con la cámara de documentos, que detecta los bordes del ticket por ti.
• Revisar y editar comercio, fecha, total, divisa, NIF, base imponible, tipo de IVA y cuota de IVA antes de guardar.
• Mantener un historial de tus tickets en tu dispositivo.
• Exportar los tickets en CSV (se abre en Excel y Numbers) o en un PDF imprimible con totales por divisa, para las fechas que elijas. Útil para tu gestor o para una nota de gastos.
• Leer tickets en español, inglés, alemán y francés. La app está disponible en esos mismos cuatro idiomas.
• Compatible con el modo oscuro y con tamaños de texto grandes.

CONVIENE SABER
• Receipt Scanner lee tickets impresos. El resultado depende de la foto y de la calidad de la impresión, así que comprueba siempre los datos antes de guardar.
• La foto del ticket no se conserva. Solo se guardan el texto extraído y los campos, en tu dispositivo.
• La app no da asesoramiento fiscal ni contable.

Dudas o problemas: https://github.com/Cosmichomeless/RECEIPT-SCANNER/blob/main/docs/support.md
```

**Novedades (1.0.0):**

```
Primera versión.
```

## Category, price and other fields

| Field | Proposal |
|-------|----------|
| Primary category | Finance |
| Secondary category | Productivity (or Business) |
| Price | Free, no in-app purchases (the goal is to launch without monetization) |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY: 1`); portrait |
| Version / build | 1.0.0 (1) |
| Content rights | Does not contain, show or access third-party content |
| Advertising identifier (IDFA) | No |

## Screenshot captions (value messages, not just screens)

Needed sizes: 6.9" (1320x2868) is mandatory; #47 also asks for 6.5". Capture them from the simulator named
"iPhone 17 Pro Max" with the demo data in [demo.md](../demo.md) (do not commit them). Suggested order and captions:

| # | Screen | English caption | Español |
|---|--------|-----------------|---------|
| 1 | Scan | Scan any receipt in seconds | Escanea cualquier ticket en segundos |
| 2 | Review | Check every detail before you save | Revisa cada dato antes de guardar |
| 3 | Review with a highlighted field | It asks instead of guessing | Pregunta en vez de adivinar |
| 4 | VAT fields | VAT, base and tax ID, ready for your accountant | IVA, base y NIF, listos para tu gestor |
| 5 | Export | Export to CSV or PDF | Exporta a CSV o PDF |
| 6 | History | Private: everything stays on your iPhone | Privado: todo se queda en tu iPhone |
