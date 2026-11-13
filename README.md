# Kentr

Al je auto's op één plek. Kentr houdt elke auto bij die je hebt gehad – met kenteken of alleen merk en type – en haalt gegevens op bij de RDW (Open Data): techniek, APK, catalogusprijs (fiscale waarde), bruto BPM en een indicatie van de bijtelling. Vergeten kenteken? Zoek het terug op merk, model, kleur en bouwjaar.

- **Bundle ID:** `app.lrvdlinden.kentr` · **Team:** EU3UY476T6
- **Platform:** iPhone en iPad, iOS 17+
- **Taal:** Nederlands
- **Data:** SwiftData + CloudKit (`iCloud.app.lrvdlinden.kentr`), app-vergrendeling met Face ID
- **Bron:** [RDW Open Data](https://opendata.rdw.nl) – *Gekentekende voertuigen* (m9d7-ebf2) en *Brandstof* (8ys7-d773), geen API-sleutel nodig
- **Foto's:** automatische voorbeeldfoto per model via Wikipedia/Wikimedia Commons API (`Services/CarPhotoService.swift`), met bronvermelding; uit te zetten in Instellingen
- **Website:** https://kent.lrvdlinden.app (map `web/`, zelf uploaden)

## Openen

Open `Kentr.xcodeproj` in Xcode 16 of nieuwer. De map `Kentr/` is een gesynchroniseerde groep: nieuwe bestanden daarin komen automatisch in het target.

Eenmalig in het developer-account:
1. App ID `app.lrvdlinden.kentr` met iCloud (CloudKit) en Push Notifications (nodig voor CloudKit-sync op de achtergrond).
2. iCloud-container `iCloud.app.lrvdlinden.kentr`.

## Structuur

| Map | Inhoud |
|---|---|
| `App/` | App, RootView (splash → onboarding → vergrendeling → tabs), router, config |
| `Core/` | Thema, kentekenopmaak, Face ID-lock, review-prompt, opmaak |
| `Models/` | `Car` (SwiftData) en `CarDraft` |
| `Services/` | RDW-client, RDW-voertuigmodel, bijtelling |
| `Views/` | Mijn auto's, Opzoeken, Terugvinden, Overzicht, Instellingen |

## Bijtelling

`Services/Bijtelling.swift` bevat de tarieven t/m 2027 (22% standaard; verlaagd tarief + cap voor volledig elektrisch per startjaar; youngtimer 35% van de dagwaarde). **Jaarlijks bijwerken** (`nulEmissie` en `tarievenTotEnMet`). Het blijft een indicatie, geen fiscaal advies.
