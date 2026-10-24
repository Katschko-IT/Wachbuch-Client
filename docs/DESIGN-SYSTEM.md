# Wachbuch Design System – „Wachbuch Klar 2“

Stand: 24. Oktober 2026. Gemeinsames Designsystem von Web-PWA und App
(Wachbuch-Client, iOS/Android).

- **Web:** Tokens am Anfang, Komponenten am Ende von
  `core/static/core/app.css` im Server-Repo `rettungswache-wachbuch`.
- **App (dieses Repo, Wachbuch-Client):** `lib/theme/design_tokens.dart`
  (Tokens, `WachbuchColors` als ThemeExtension), `lib/theme/app_theme.dart`
  (ThemeData), `lib/theme/high_contrast_theme.dart`.

Die Token-Namen sind in beiden Welten gleich – im Web als CSS-Variable in
kebab-case, in der App in camelCase (`--line-strong` → `lineStrong`,
`--brand-deep` → `brandDeep`).

## Prinzipien

1. **Ruhige Flächen, Farbe nur für Zustand und Bedienung.** Blau („Blaulicht“)
   kennzeichnet ausschließlich Aktionen, Auswahl und aktive Navigation.
2. **WCAG 2.2 AA als Untergrenze.** Text ≥ 4,5:1, Begrenzungen von
   Bedienelementen (`lineStrong`) ≥ 3:1 – beides per Test abgesichert.
3. **48 dp Touch-Ziele** – bedienbar mit Handschuhen und in Eile.
4. **Zustand nie nur über Farbe:** Etiketten tragen immer ausgeschriebenen Text,
   die Farbe kommt als Punkt und Rand hinzu.
5. **Nachtdienst zuerst mitgedacht:** Dunkelmodus mit gedämpften Signalen,
   zeitabhängig per Sonnenstand umgeschaltet.
6. **Ein Markenelement:** die Warnmarkierung (Schrägstreifen), sonst keine
   Dekoration.

## Farben

Alle Farben stehen in `WachbuchColors` (`WachbuchColors.light`,
`WachbuchColors.dark`, plus Hochkontrast-Varianten). Zugriff in Widgets:

```dart
final c = WachbuchColors.of(context);
Container(color: c.surfaceSoft, child: Text('…', style: TextStyle(color: c.text)));
```

| Token | Hell | Dunkel | Verwendung |
| --- | --- | --- | --- |
| `bg` | `#F5F7F6` | `#0D141A` | Seitenhintergrund |
| `surface` | `#FFFFFF` | `#151E26` | Karten, Kopfleiste, Navigation, Dialoge |
| `surfaceSoft` | `#EEF2F1` | `#1C2731` | ruhige Hinterlegung, neutrale Chips |
| `text` | `#14212B` | `#E7ECEF` | Lesetext |
| `muted` | `#4D5B66` | `#A6B3BD` | Nebentext (≥ 4,5:1) |
| `line` | `#D7DDE1` | `#2B3843` | dekorative Linien, Kartenrand |
| `lineStrong` | `#6F7D88` | `#6D7C88` | Rand von Eingaben/Bedienelementen (≥ 3:1) |
| `brand` | `#0E4AA8` | `#8DB4FF` | Aktion „Blaulicht“, Primärbutton |
| `brandDeep` | `#0A3A85` | `#B3CCFF` | gedrückt/aktiv, Text auf `accentSoft` |
| `accentSoft` | `#E3ECFA` | `#1B2D4A` | Auswahl, Navigationsindikator |
| `onPrimary` | `#FFFFFF` | `#0A1A33` | Text auf `brand` |
| `danger` / `dangerSoft` | `#B81D18` / `#FCEBEA` | `#FF8F86` / `#3A1714` | Fehler, dringend |
| `warning` / `warningSoft` | `#8A4B00` / `#FDF2DF` | `#FFC966` / `#33260C` | Warnung (Textfarbe) |
| `warningAccent` | `#F2A900` | `#F2A900` | Warnsignal als Punkt/Rand, nie als Text |
| `success` / `successSoft` | `#136B3A` / `#E5F4EA` | `#6FD49A` / `#11301F` | erledigt, einsatzbereit |
| `info` / `infoSoft` | = `brand` / `accentSoft` | = `brand` / `accentSoft` | Hinweis, offen |
| `focus` | `#F2A900` | `#F2A900` | Fokusring |
| `stripeRed` | `#E2231A` | `#E2231A` | Warnmarkierung |
| `stripeWhite` | `#FFFFFF` | `#C9D2D8` | Warnmarkierung |

### Abbildung auf Material 3

`app_theme.dart` erzeugt das `ColorScheme` aus diesen Tokens:
`primary = brand`, `primaryContainer = accentSoft`, `onPrimaryContainer =
brandDeep`, `error = danger` (einzige Fehlerfarbe), `errorContainer =
dangerSoft`, `surface = surface`, `onSurface = text`, `onSurfaceVariant =
muted`, `outline = lineStrong`, `outlineVariant = line`,
`surfaceContainer*` = `surface`/`surfaceSoft`. Neue Widgets nutzen bevorzugt
`WachbuchColors`, weil dort auch `warningAccent`, die `-soft`-Flächen und die
Streifenfarben passend zum Modus liegen.

## Statusbedeutung (verbindlich für Web und App)

| Bedeutung | Werte | Ton | Punkt | Text | Fläche |
| --- | --- | --- | --- | --- | --- |
| dringend | Priorität `urgent`/`high`, Status `urgent` | danger | `danger` | `danger` | `dangerSoft` |
| offen | `open`, `new` | info | `brand` | `text` | `accentSoft` |
| in Arbeit | `in_progress`, `active` | warning | `warningAccent` | `warning` | `warningSoft` |
| wartend | `waiting`, `blocked` | neutral | `muted` | `text` | `surface` |
| erledigt | `done`, `closed` | success | `success` | `success` | `successSoft` |

Prioritäten: dringend = danger, wichtig (`important`/`medium`) = warning,
normal = info, erledigt (`done`/`low`) = success.

Umsetzung: `WachbuchTokens.statusTone()` / `priorityTone()` liefern den Ton,
`WachbuchColors.tone()` / `status()` / `priority()` die Farben
(`foreground`, `background`, `accent`, `border`). Eigene Farbzuordnungen in
Screens sind nicht erlaubt.

## Typografie

Hausschrift **Atkinson Hyperlegible Next** (SIL Open Font License 1.1),
Schnitte 400/600/700, als TTF unter `assets/fonts/` (Quelle:
`googlefonts/atkinson-hyperlegible-next`, `fonts/ttf`). Die Lizenz liegt
daneben und ist über `LicenseRegistry` in der Lizenzübersicht der App
eingetragen (`lib/theme/font_license.dart`).

Zahlen in Kennzahlen, Zählern, Beträgen und Uhrzeiten nutzen **tabellarische
Ziffern** (`WachbuchTokens.tabularFigures`); im TextTheme sind `display*`,
`headline*` und `label*` damit vorbelegt.

| Rolle | Größe | Gewicht |
| --- | --- | --- |
| Caption | 12 sp | 400, nur ergänzend |
| Body | 14–16 sp | 400 |
| Title | 16 sp | 600 |
| Headline | 20 sp | 700 |
| Display | 28 sp | 700 |

## Abstände, Radien, Größen

| Token | Wert |
| --- | --- |
| `space1` … `space7` (`spaceXs` … `space3Xl`) | 4 / 8 / 12 / 16 / 24 / 32 / 48 |
| `radiusSm` / `radiusMd` / `radiusLg` | 6 / 10 / 14 |
| `touchTarget` | 48 |
| `inputHeight` | 56 |
| `stripeHeight` | 4 |

Literale außerhalb der Skala sind zu vermeiden.

## Komponenten

| Komponente | Datei | Regeln |
| --- | --- | --- |
| Buttons | `app_theme.dart` | Mindesthöhe 48 dp, Radius `radiusMd`, Primär = `brand`/`onPrimary`, Outline = `brand` |
| Eingaben | `app_theme.dart` | Rand `lineStrong`, Fokus `brand` 2 px, Fehler `danger`, Höhe ≥ 56 |
| Karten | `app_theme.dart` | `surface`, ohne Schatten, Rand `line`, Radius `radiusLg` |
| NavigationBar/-Rail | `app_theme.dart` | `surface`, Indikator `accentSoft`, aktiv `brandDeep` |
| Dialoge, Sheets, SnackBars | `app_theme.dart` | ohne Schatten; SnackBar invers (`text` auf `surface`) |
| StatusChip | `lib/ui/status_chip.dart` | Statusbedeutung s. o.; Text in Lesefarbe, Punkt + Rand |
| PriorityBadge | `lib/ui/priority_badge.dart` | wie StatusChip, Prioritätstöne |
| EmptyState | `lib/ui/empty_state.dart` | Icon, Titel, erklärender Text, optionale Aktion (z. B. Aktualisieren) |
| SectionTitle | `lib/ui/section_title.dart` | Icon in `brand`, Titel `titleMedium`, als Überschrift markiert |
| ErrorBanner | `lib/ui/error_banner.dart` | `dangerSoft` mit `danger`-Rand, Live-Region |
| DemoBanner | `lib/ui/demo_banner.dart` | `warningSoft`, Unterkante `warningAccent` |
| WarnStripe | `lib/ui/warn_stripe.dart` | Markenelement, s. u. |
| CopyIconButton | `lib/ui/copy_button.dart` | Clipboard + SnackBar, 48 dp |

Icons ausschließlich als Material Icons – keine Emojis in der Oberfläche.

### Warnmarkierung

Schrägstreifen in `stripeRed`/`stripeWhite` (wie am Heck eines
Rettungswagens), gezeichnet per `CustomPainter`. Einzige Verwendung: 4 px hohes
Band oben in der Kopfleiste der Hauptansicht (`home_shell.dart`) – entspricht
`.app-header::before` im Web. Für Screenreader ausgeblendet. Nicht an weiteren
Stellen einsetzen.

## Themes

- **Hell/Dunkel (Solar):** `buildWachbuchTheme(Brightness)`; beide Themes
  tragen `WachbuchColors` als Extension. `SolarThemeController`
  (`lib/theme/solar_theme.dart`) schaltet nach Sonnenauf-/-untergang zwischen
  `ThemeMode.light` und `ThemeMode.dark`, sonst folgt die App dem System.
- **Hochkontrast:** `HighContrastTheme.light()/dark()` bauen über
  `buildWachbuchThemeFrom()` auf denselben Tokens auf (Schwarz/Weiß, Ränder in
  Textfarbe, größere Schrift; Zustandsfarben bleiben). `MaterialApp` nutzt sie,
  sobald das System erhöhten Kontrast meldet.

## Barrierefreiheit

- **Kontrast:** `test/design_tokens_test.dart` berechnet den WCAG-Kontrast für
  hell und dunkel (`text`/`surface` ≥ 4,5:1, `lineStrong`/`surface` ≥ 3:1,
  Etikettentexte auf ihrer Fläche ≥ 4,5:1).
- **Touch-Ziele:** 48 dp für interaktive Elemente.
- **Text-Skalierung:** scrollbare Detailansichten, adaptive Kachelspalten.
- **Screenreader:** Labels auf Icons, Überschriften markiert, Zustand nie nur
  über Farbe.
- **Reduced Motion:** keine Information hängt von Animation ab.

Manuelle Abnahme mit VoiceOver/TalkBack, 200–400 % Text-/Zoom-Szenarien und
kleinen Displays bleibt Teil der Pilotfreigabe.

## Rettungsdienst-spezifische Muster

1. **Dringend-Badge in Navigation:** Anzahl dringender Übergaben
2. **Große Saldo-Anzeige:** Kaffeekasse-Saldo mit tabellarischen Ziffern
3. **Schnellzugriff-Kacheln:** Dashboard-Module groß und gut tippbar
4. **Offline-Indikator:** sichtbares Banner; Lese-Snapshots verschlüsselt und tokengebunden
5. **Demo-Modus-Banner:** deutliches Band für Musterdaten
6. **Mängel-Fotos:** explizite Kamera/Galerie-Aktion mit Datenschutz-Hinweis
