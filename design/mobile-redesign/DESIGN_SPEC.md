# FreestyleCombo — Mobile Redesign Spec

Visual target for the Flutter client. **Redesign only** — keep all existing API calls, models,
`api_client.dart`, `auth_service.dart`, and `app_router.dart`. Open `mocks.html` in a browser to
see the 9 reference screens; `preview.png` is a quick thumbnail.

Skip **Level / streak / OAuth** — those are placeholder concepts not backed by the current API.

---

## Design tokens

```dart
// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  static const indigo    = Color(0xFF4F46E5);
  static const indigoD   = Color(0xFF3F37C9);
  static const violet    = Color(0xFF7A5AF0);
  static const lime      = Color(0xFFC6F135); // energy accent — generate / highlights
  static const limeText  = Color(0xFF26310A);

  static const ink       = Color(0xFF15131F); // primary text
  static const ink2      = Color(0xFF3A3752);
  static const muted     = Color(0xFF7C7A93);
  static const faint     = Color(0xFFA9A7BC);

  static const bg        = Color(0xFFF4F4F9); // screen background
  static const surface   = Color(0xFFFFFFFF);
  static const line      = Color(0xFFECEBF3);
  static const line2     = Color(0xFFE3E2EE);

  // difficulty scale
  static const green   = Color(0xFF16A34A); static const greenBg = Color(0xFFDCFCE7); // 1–4
  static const amber   = Color(0xFFB45309); static const amberBg = Color(0xFFFEF3C7); // 5–7
  static const red     = Color(0xFFDC2626); static const redBg   = Color(0xFFFEE2E2); // 8–10

  static const grad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF5B4FE9), Color(0xFF7A5AF0), Color(0xFF8E6BF5)],
  );
}
```

```dart
// lib/main.dart — theme
theme: ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    primary: AppColors.indigo,
    surface: AppColors.surface,
  ),
  fontFamily: 'PlusJakartaSans', // via google_fonts: GoogleFonts.plusJakartaSans
),
```

### Type
- **UI:** Plus Jakarta Sans — weights 400/600/700/800.
- **Combo & trick notation** (abbreviations, positions, numeric stats): **JetBrains Mono** 500/700.
- Titles ~27px/800 letter-spacing -0.6; card titles 17px/800; body 14–15px.
- Add both via `google_fonts` (easiest) or bundle in `pubspec.yaml` `fonts:`.

### Shape & elevation
- Cards: radius **24**, 1px `line` border, soft shadow `0 8px 24px -16px rgba(20,18,31,.18)`.
- Rows / inputs / chips: radius **12–18**.
- Buttons: radius **16**, height ~52, weight 800.
- Primary button / badge / FAB: `AppColors.grad`. Lime button only for the Generate hero action.
- Difficulty badge on cards: gradient tile, big mono number + tiny "DIFF" label.

### Spacing
- Screen horizontal padding **22**; card padding **18**; 14 between cards.

---

## Components

**DifficultyChip(int d)** → greenBg/green (1–4), amberBg/amber (5–7), redBg/red (8–10). Small mono number.

**ComboCard** (refactor existing `combo_card.dart`)
- Row: name (17/800) + `by <owner>` (indigo link) on left, gradient DIFF badge right.
- Trick chips: `1. ATW` mono, position number in faint. No-touch chips tinted `#EDE9FE`/`#6D28D9`.
  "+N" overflow chip in ink/white. Cap visible at 6, expand inline (keep existing logic).
- Footer row (top-border): ★ rating (amber), ♥ favourites count (pink), ✓ done count (green),
  spacer, visibility tag (Public=blue, Pending=amber, Private=grey). Keep existing toggle logic.

**Bottom nav** (`main_shell.dart`) — height ~74, white 94% + blur, top hairline.
5 slots: Combos · Tricks · **center gradient lightning button (Generate/Create)** · Presets · Profile.
Active = indigo; inactive = faint. Labels 10.5/700.

**Sliders** (generate): 8px track, gradient fill, white knob w/ 4px indigo ring, mono value label in indigo.
**Toggles:** iOS switch, indigo when on.

---

## Screens (see mocks.html, numbered)

1. **Welcome/auth** — gradient hero, white bottom sheet with fields + Log in. (Drop OAuth row if not implementing.)
2. **Combos** — segmented Public/Mine/Favourites, ComboCard list, center Generate button. `combos_screen.dart`.
3. **Generate** — preset chips, sliders (length, max diff, strong-foot %, no-touch %), 2 toggles, sticky Generate bar. `create_combo_screen.dart` (generate mode).
4. **Preview** — gradient hero stats (diff/tricks/no-touch), numbered sequence timeline, Regenerate / Save bar.
5. **Combo detail** — gradient hero (name, owner, diff/tricks/rating), AI-description card, numbered sequence w/ per-trick difficulty + wf/nt flags, Rate / Mark-as-done bar. `combo_detail_screen.dart`.
6. **Build** — name field, reorderable slots (position tile, name, SF/nt/wf flag), "Add trick", public toggle, Preview/Save bar. `create_combo_screen.dart` (build mode).
7. **Tricks** — search field, trick rows (mono abbrev tile, name, rev/type meta, difficulty chip); reusable combos shown with a COMBO tag. `tricks_screen.dart`.
8. **Presets** — preference profile cards (icon, name, Edit, 3 mono stat tiles). `preferences_screen.dart`.
9. **Profile** — gradient header (avatar, username), stat row (combos/done/avg★), account links, log out. `account_screen.dart` / profile.

---

## Order of work
1. Add `google_fonts`, `app_colors.dart`, theme in `main.dart`.
2. `DifficultyChip` + `ComboCard`.
3. `main_shell.dart` bottom nav.
4. Screens 2 → 5 → 3/6 → 7 → 8 → 9 → 1.
