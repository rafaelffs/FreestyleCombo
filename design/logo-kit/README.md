# FreestyleCombo — Logo Kit

Final identity: an **Around The World (ATW)** mark — one unbroken revolution, a solid ball riding
the path, and a lightning bolt at the centre for the app's generate action.

Reference sheet: `../FreestyleCombo Logo - Final.html`

---

## Contents

```
logo-kit/
├─ mark/                      the mark alone
│  ├─ logo-mark-gradient.svg      primary — brand gradient
│  ├─ logo-mark-gradient-512.png
│  ├─ logo-mark-indigo.svg        one colour
│  ├─ logo-mark-black.svg
│  ├─ logo-mark-white.svg         reversed, for dark surfaces
│  └─ logo-mark-on-lime.svg       ink mark, lime bolt knockout
├─ lockup/                    mark + wordmark
│  ├─ lockup-horizontal-light.svg   headers, nav
│  ├─ lockup-horizontal-dark.svg
│  ├─ lockup-horizontal-black.svg   print, one colour
│  ├─ lockup-horizontal-white.svg
│  ├─ lockup-stacked-light.svg      splash, avatars, square
│  └─ lockup-stacked-dark.svg
├─ app-icon/                  gradient tile, white mark
│  ├─ app-icon-1024.png/.svg      App Store / Play Store
│  ├─ app-icon-512.png/.svg
│  ├─ app-icon-192.png/.svg       Android / PWA
│  ├─ app-icon-180.png/.svg       iOS home screen
│  ├─ app-icon-96.png/.svg
│  └─ adaptive-icon-foreground.png/.svg   Android adaptive (432px, transparent)
└─ favicon/                   higher ring opacity so it survives small
   ├─ favicon-32.png/.svg
   ├─ favicon-20.svg
   └─ favicon-16.png/.svg
```

---

## Tokens

Identical to `../mobile-redesign/DESIGN_SPEC.md` — the logo introduces no new colours.

| Token | Value |
|---|---|
| Brand gradient | `#5B4FE9` → `#7A5AF0` (55%) → `#8E6BF5`, 135° |
| Indigo | `#4F46E5` |
| Violet (dark-surface wordmark) | `#9C8BFF` |
| Ink | `#15131F` |
| Lime accent | `#C6F135` |

**Wordmark type** — Plus Jakarta Sans.
`FREESTYLE` 800, uppercase, 3.6px tracking, indigo (violet on dark).
`Combo` 800, −0.9px tracking, ink (white on dark).

---

## Usage

**Clear space** — one traveller-ball diameter on every side (≈9% of the mark's width).

**Minimum sizes** — lockup: 40px mark. Bare mark: 24px. Gradient tile: 16px.
Below 24px use a tile, not the bare mark: the orbit ring thins out.

**Do** use the gradient on light or dark surfaces; use the white reversed mark on photography
or brand colour; use the tile for any icon slot.

**Don't** recolour the bolt, change the orbit angle (−28°), place the bare mark on busy imagery,
or add effects (shadow, outline, bevel) to the mark itself.

### The lockup SVGs use live text
`lockup-*.svg` reference **Plus Jakarta Sans** as a system font. They render correctly wherever
that font is installed — on a machine without it the text falls back to a generic sans. For
web use, load the font (`google_fonts` / Google Fonts CSS) and the SVG matches the reference
sheet. For print or handoff to someone without the font, build the lockup from
`mark/logo-mark-*.svg` plus live text in your layout tool, or ask for an outlined version.

---

## Wiring it up

**Flutter** — put the SVGs in `mobile/assets/brand/`, add to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/brand/
```

Use with `flutter_svg`:

```dart
SvgPicture.asset('assets/brand/logo-mark-gradient.svg', width: 40)
```

App icons via `flutter_launcher_icons`:

```yaml
flutter_launcher_icons:
  image_path: "assets/brand/app-icon-1024.png"
  android: true
  ios: true
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/brand/adaptive-icon-foreground.png"
```

**Web** — in `<head>`:

```html
<link rel="icon" type="image/svg+xml" href="/favicon/favicon-32.svg">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon/favicon-32.png">
<link rel="apple-touch-icon" sizes="180x180" href="/app-icon/app-icon-180.png">
```

---

## Replacing the old identity

The previous site used a plain indigo wordmark with no mark. Swap in:

- **Nav / header** → `lockup/lockup-horizontal-light.svg`
- **Footer on dark** → `lockup/lockup-horizontal-dark.svg`
- **Favicon** → `favicon/favicon-32.svg` + `.png` fallback
- **Mobile splash & app icon** → `app-icon/` set
- **Avatar / social profile** → `lockup/lockup-stacked-light.svg` or the bare gradient mark
