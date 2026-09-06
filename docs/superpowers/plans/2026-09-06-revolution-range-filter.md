# Revolution Range Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users restrict combo generation/preview to a contiguous min–max revolution-count band (e.g. "2.0–3.0 revs only") from both the saved-preference form and the generate screen's "Custom" quick-overrides panel, on web and mobile.

**Architecture:** Frontend-only. The backend field this reuses — `AllowedRevolutions: List<decimal>` on `UserPreference` and `GenerateComboOverrides` — already exists, is already validated, and is already applied in pool filtering; it just has no UI anywhere today. A small pure `encode(min, max) -> list` / `decode(list) -> {min, max}` helper on each platform converts between the new range control and that existing list field. A full-range selection (0.5–4.0) encodes to an empty list, matching the existing "no restriction" semantics.

**Tech Stack:** React + TypeScript + Tailwind (web), Flutter/Dart (mobile). No backend changes, no new dependencies on either platform.

**Spec:** `docs/superpowers/specs/2026-09-06-revolution-range-filter-design.md`

---

## File Map

| File | Change |
|---|---|
| `web/src/lib/revolutionRange.ts` | Create — `encodeRevolutionRange`/`decodeRevolutionRange` + constants |
| `web/src/components/ui/rev-range-slider.tsx` | Create — `RevRangeSlider` dual-thumb control |
| `web/src/locales/en.json`, `web/src/locales/pt-BR.json` | Modify — new i18n keys |
| `web/src/features/preferences/PreferencesPage.tsx` | Modify — add control to `PreferenceForm`, summary line to `PreferenceCard` |
| `web/src/features/combos/CreateComboPage.tsx` | Modify — add control to generate-mode quick-overrides panel |
| `mobile/lib/core/models/revolution_range.dart` | Create — Dart equivalent helpers |
| `mobile/test/revolution_range_test.dart` | Create — unit tests for the helpers |
| `mobile/lib/core/models/combo.dart` | Modify — add missing `allowedRevolutions` field to `GenerateComboOverrides` |
| `mobile/lib/features/preferences/preferences_screen.dart` | Modify — add `_PrefRangeSlider`, wire state, save, card caption |
| `mobile/lib/features/combos/create_combo_screen.dart` | Modify — add `_AppRangeSlider`, wire state, preset copy/reset, preview call |
| `CLAUDE.md` | Modify — document the new UI per the file's own "update docs" instruction |

---

### Task 1: Web revolution-range helper

**Files:**
- Create: `web/src/lib/revolutionRange.ts`

- [ ] **Step 1: Write the helper module**

```ts
export const REV_MIN = 0.5
export const REV_MAX = 4
export const REV_STEP = 0.5

/**
 * A full-range selection (REV_MIN..REV_MAX) encodes to an empty list, matching
 * the existing "empty AllowedRevolutions = no restriction" backend semantics.
 */
export function encodeRevolutionRange(min: number, max: number): number[] {
  if (min <= REV_MIN && max >= REV_MAX) return []
  const steps = Math.round((max - min) / REV_STEP)
  const result: number[] = []
  for (let i = 0; i <= steps; i++) {
    result.push(Math.round((min + i * REV_STEP) * 2) / 2)
  }
  return result
}

export function decodeRevolutionRange(list: number[]): { min: number; max: number } {
  if (list.length === 0) return { min: REV_MIN, max: REV_MAX }
  return { min: Math.min(...list), max: Math.max(...list) }
}
```

- [ ] **Step 2: Type-check**

Run: `cd web && npx tsc -b --noEmit`
Expected: no errors (this file has no dependents yet, so this just confirms the new file itself compiles).

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/revolutionRange.ts
git commit -m "$(cat <<'EOF'
Add revolution range encode/decode helpers (web)

Pure functions converting a min/max pair to/from the existing
AllowedRevolutions list field, so the upcoming range-slider UI can reuse
that field with no backend changes.
EOF
)"
```

---

### Task 2: Web `RevRangeSlider` component

**Files:**
- Create: `web/src/components/ui/rev-range-slider.tsx`

- [ ] **Step 1: Write the component**

```tsx
import { REV_MAX, REV_MIN, REV_STEP } from '@/lib/revolutionRange'

interface RevRangeSliderProps {
  min: number
  max: number
  onChange: (min: number, max: number) => void
  disabled?: boolean
}

const THUMB_CLASS =
  '[&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 ' +
  '[&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border-2 [&::-webkit-slider-thumb]:bg-white ' +
  '[&::-webkit-slider-thumb]:pointer-events-auto [&::-webkit-slider-thumb]:cursor-pointer ' +
  '[&::-moz-range-thumb]:h-4 [&::-moz-range-thumb]:w-4 [&::-moz-range-thumb]:rounded-full ' +
  '[&::-moz-range-thumb]:border-2 [&::-moz-range-thumb]:bg-white [&::-moz-range-thumb]:pointer-events-auto ' +
  '[&::-moz-range-thumb]:cursor-pointer [&::-webkit-slider-runnable-track]:bg-transparent ' +
  '[&::-moz-range-track]:bg-transparent'

/**
 * Two overlaid native range inputs is a standard CSS-only dual-range-slider
 * pattern: each input is full-width and pointer-events-none except its own
 * thumb, so only the thumbs are draggable and they never fight over clicks
 * on the track.
 */
export function RevRangeSlider({ min, max, onChange, disabled = false }: RevRangeSliderProps) {
  const isFullRange = min <= REV_MIN && max >= REV_MAX
  const label = isFullRange ? 'All revolutions' : `Revs: ${min.toFixed(1)} – ${max.toFixed(1)}`
  const thumbBorder = disabled
    ? '[&::-webkit-slider-thumb]:border-gray-300 [&::-moz-range-thumb]:border-gray-300'
    : '[&::-webkit-slider-thumb]:border-indigo-600 [&::-moz-range-thumb]:border-indigo-600'

  function handleMinChange(value: number) {
    onChange(Math.min(value, max), max)
  }

  function handleMaxChange(value: number) {
    onChange(min, Math.max(value, min))
  }

  return (
    <div className="space-y-1">
      <span className={`text-sm ${disabled ? 'text-gray-400' : 'text-gray-700'}`}>{label}</span>
      <div className="relative h-6">
        <div className="absolute top-1/2 left-0 right-0 h-1 -translate-y-1/2 rounded-full bg-gray-200" />
        <div
          className={`absolute top-1/2 h-1 -translate-y-1/2 rounded-full ${disabled ? 'bg-gray-300' : 'bg-indigo-500'}`}
          style={{
            left: `${((min - REV_MIN) / (REV_MAX - REV_MIN)) * 100}%`,
            right: `${100 - ((max - REV_MIN) / (REV_MAX - REV_MIN)) * 100}%`,
          }}
        />
        <input
          type="range"
          min={REV_MIN}
          max={REV_MAX}
          step={REV_STEP}
          value={min}
          disabled={disabled}
          onChange={(e) => handleMinChange(Number(e.target.value))}
          className={`pointer-events-none absolute inset-x-0 top-0 h-6 w-full appearance-none bg-transparent ${THUMB_CLASS} ${thumbBorder}`}
        />
        <input
          type="range"
          min={REV_MIN}
          max={REV_MAX}
          step={REV_STEP}
          value={max}
          disabled={disabled}
          onChange={(e) => handleMaxChange(Number(e.target.value))}
          className={`pointer-events-none absolute inset-x-0 top-0 h-6 w-full appearance-none bg-transparent ${THUMB_CLASS} ${thumbBorder}`}
        />
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Type-check and lint**

Run: `cd web && npx tsc -b --noEmit && npm run lint`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add web/src/components/ui/rev-range-slider.tsx
git commit -m "$(cat <<'EOF'
Add RevRangeSlider dual-thumb component (web)

Standalone control, not wired into any page yet. Follows the same plain-
Tailwind, no-new-dependency style as the existing FootToggle control.
EOF
)"
```

---

### Task 3: Web i18n keys

**Files:**
- Modify: `web/src/locales/en.json`
- Modify: `web/src/locales/pt-BR.json`

- [ ] **Step 1: Add keys to `en.json`'s `create` section**

Find (around line 153):
```json
    "maxHighRevTricks": "Max 3+ Rev Tricks",
    "includeCrossover": "Include Crossover",
```

Replace with:
```json
    "maxHighRevTricks": "Max 3+ Rev Tricks",
    "revRange": "Revolutions",
    "includeCrossover": "Include Crossover",
```

- [ ] **Step 2: Add keys to `en.json`'s `preferences` section**

Find (around line 355):
```json
    "maxHighRevTricks": "Max 3+ Rev Tricks",
    "maxHighRevLabel": "Max 3+ rev",
    "allowedTricks": "Allowed Tricks",
```

Replace with:
```json
    "maxHighRevTricks": "Max 3+ Rev Tricks",
    "maxHighRevLabel": "Max 3+ rev",
    "revRange": "Revolutions",
    "revRangeLabel": "Revs",
    "allowedTricks": "Allowed Tricks",
```

- [ ] **Step 3: Add keys to `pt-BR.json`'s `create` section**

Find (around line 153):
```json
    "maxHighRevTricks": "Máx tricks 3+ giros",
    "includeCrossover": "Incluir Crossover",
```

Replace with:
```json
    "maxHighRevTricks": "Máx tricks 3+ giros",
    "revRange": "Giros",
    "includeCrossover": "Incluir Crossover",
```

- [ ] **Step 4: Add keys to `pt-BR.json`'s `preferences` section**

Find (around line 355):
```json
    "maxHighRevTricks": "Máx tricks 3+ giros",
    "maxHighRevLabel": "Máx 3+ giros",
    "allowedTricks": "Tricks Permitidas",
```

Replace with:
```json
    "maxHighRevTricks": "Máx tricks 3+ giros",
    "maxHighRevLabel": "Máx 3+ giros",
    "revRange": "Giros",
    "revRangeLabel": "Giros",
    "allowedTricks": "Tricks Permitidas",
```

- [ ] **Step 5: Verify both files are still valid JSON**

Run: `cd web && node -e "require('./src/locales/en.json'); require('./src/locales/pt-BR.json'); console.log('OK')"`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add web/src/locales/en.json web/src/locales/pt-BR.json
git commit -m "$(cat <<'EOF'
Add i18n keys for the revolution range filter (web)

EOF
)"
```

---

### Task 4: Wire into web `PreferencesPage.tsx`

**Files:**
- Modify: `web/src/features/preferences/PreferencesPage.tsx`

- [ ] **Step 1: Add imports**

Find:
```tsx
import { preferencesApi, tricksApi, extractError, type UserPreference, type PreferencePayload, type TrickItem } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
```

Replace with:
```tsx
import { preferencesApi, tricksApi, extractError, type UserPreference, type PreferencePayload, type TrickItem } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { RevRangeSlider } from '@/components/ui/rev-range-slider'
import { decodeRevolutionRange, encodeRevolutionRange } from '@/lib/revolutionRange'
```

- [ ] **Step 2: Add the range control to `PreferenceForm`, right after "Max 3+ Rev Tricks"**

Find:
```tsx
        <div className="space-y-1">
          <Label>{t('preferences.maxHighRevTricks')}</Label>
          <Input
            type="number"
            min={1}
            max={15}
            value={form.maxHighRevolutionTricks ?? 1}
            onChange={(e) => update('maxHighRevolutionTricks', Math.min(15, Math.max(1, Number(e.target.value))))}
          />
        </div>
      </div>
```

Replace with:
```tsx
        <div className="space-y-1">
          <Label>{t('preferences.maxHighRevTricks')}</Label>
          <Input
            type="number"
            min={1}
            max={15}
            value={form.maxHighRevolutionTricks ?? 1}
            onChange={(e) => update('maxHighRevolutionTricks', Math.min(15, Math.max(1, Number(e.target.value))))}
          />
        </div>
        <div className="space-y-1 sm:col-span-2 md:col-span-3">
          <Label>{t('preferences.revRange')}</Label>
          <RevRangeSlider
            min={decodeRevolutionRange(form.allowedRevolutions).min}
            max={decodeRevolutionRange(form.allowedRevolutions).max}
            onChange={(min, max) => update('allowedRevolutions', encodeRevolutionRange(min, max))}
          />
        </div>
      </div>
```

- [ ] **Step 3: Add a `revRange` summary to `PreferenceCard`**

Find:
```tsx
  const stats = t('preferences.stats', {
    length: pref.comboLength,
    maxDiff: pref.maxDifficulty,
    sf: pref.strongFootPercentage,
    nt: pref.noTouchPercentage,
  })
```

Replace with:
```tsx
  const stats = t('preferences.stats', {
    length: pref.comboLength,
    maxDiff: pref.maxDifficulty,
    sf: pref.strongFootPercentage,
    nt: pref.noTouchPercentage,
  })
  const revRange = pref.allowedRevolutions.length > 0 ? decodeRevolutionRange(pref.allowedRevolutions) : null
```

Find:
```tsx
            {pref.maxHighRevolutionTricks != null && <> · {t('preferences.maxHighRevLabel')} {pref.maxHighRevolutionTricks}</>}
            {pref.allowedTrickIds.length > 0 && (
```

Replace with:
```tsx
            {pref.maxHighRevolutionTricks != null && <> · {t('preferences.maxHighRevLabel')} {pref.maxHighRevolutionTricks}</>}
            {revRange && <> · {t('preferences.revRangeLabel')} {revRange.min.toFixed(1)}–{revRange.max.toFixed(1)}</>}
            {pref.allowedTrickIds.length > 0 && (
```

- [ ] **Step 4: Type-check and lint**

Run: `cd web && npx tsc -b --noEmit && npm run lint`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add web/src/features/preferences/PreferencesPage.tsx
git commit -m "$(cat <<'EOF'
Wire revolution range filter into the preference form (web)

Adds the RevRangeSlider control to PreferenceForm and a summary snippet
to PreferenceCard, both keyed off the existing allowedRevolutions field.
EOF
)"
```

---

### Task 5: Wire into web `CreateComboPage.tsx`

**Files:**
- Modify: `web/src/features/combos/CreateComboPage.tsx`

- [ ] **Step 1: Add imports**

Find:
```tsx
import { isAuthenticated, setPendingCombo } from '@/lib/auth'
import { getShowDifficulty } from '@/lib/displayPrefs'
```

Replace with:
```tsx
import { isAuthenticated, setPendingCombo } from '@/lib/auth'
import { getShowDifficulty } from '@/lib/displayPrefs'
import { decodeRevolutionRange, encodeRevolutionRange } from '@/lib/revolutionRange'
```

Find:
```tsx
import { Badge } from '@/components/ui/badge'
```

Replace with:
```tsx
import { Badge } from '@/components/ui/badge'
import { RevRangeSlider } from '@/components/ui/rev-range-slider'
```

- [ ] **Step 2: Compute the effective range once, next to `selectedPref`**

Find:
```tsx
  const selectedPref = selectedPrefId ? savedPrefs.find((p) => p.id === selectedPrefId) ?? null : null
```

Replace with:
```tsx
  const selectedPref = selectedPrefId ? savedPrefs.find((p) => p.id === selectedPrefId) ?? null : null
  const revRange = decodeRevolutionRange(selectedPref ? selectedPref.allowedRevolutions : (overrides.allowedRevolutions ?? []))
```

- [ ] **Step 3: Add the range control to the quick-overrides fields grid, right after "Max 3+ Rev Tricks"**

Find:
```tsx
              <div className="space-y-1">
                <Label>{t('create.maxHighRevTricks')}</Label>
                <Input
                  type="number" min={1} max={15}
                  value={(selectedPref ? selectedPref.maxHighRevolutionTricks : overrides.maxHighRevolutionTricks) ?? 1}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxHighRevolutionTricks', Math.min(15, Math.max(1, Number(e.target.value))))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
```

Replace with:
```tsx
              <div className="space-y-1">
                <Label>{t('create.maxHighRevTricks')}</Label>
                <Input
                  type="number" min={1} max={15}
                  value={(selectedPref ? selectedPref.maxHighRevolutionTricks : overrides.maxHighRevolutionTricks) ?? 1}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxHighRevolutionTricks', Math.min(15, Math.max(1, Number(e.target.value))))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1 sm:col-span-2 md:col-span-3">
                <Label>{t('create.revRange')}</Label>
                <RevRangeSlider
                  min={revRange.min}
                  max={revRange.max}
                  disabled={!!selectedPref}
                  onChange={(min, max) => updateOverride('allowedRevolutions', encodeRevolutionRange(min, max))}
                />
              </div>
```

- [ ] **Step 4: Type-check, lint, and build**

Run: `cd web && npm run build`
Expected: build succeeds with no TypeScript errors.

- [ ] **Step 5: Commit**

```bash
git add web/src/features/combos/CreateComboPage.tsx
git commit -m "$(cat <<'EOF'
Wire revolution range filter into generate quick-overrides (web)

Same RevRangeSlider control, locked/disabled when a saved preference is
selected — matching the pattern already used by every other override
field on this panel.
EOF
)"
```

---

### Task 6: Mobile revolution-range helper + tests

**Files:**
- Create: `mobile/lib/core/models/revolution_range.dart`
- Create: `mobile/test/revolution_range_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_combo/core/models/revolution_range.dart';

void main() {
  group('encodeRevolutionRange', () {
    test('full range encodes to empty list (no filter)', () {
      expect(encodeRevolutionRange(0.5, 4.0), isEmpty);
    });

    test('2.0-3.0 encodes to [2.0, 2.5, 3.0]', () {
      expect(encodeRevolutionRange(2.0, 3.0), [2.0, 2.5, 3.0]);
    });

    test('single-value range encodes to one item', () {
      expect(encodeRevolutionRange(1.5, 1.5), [1.5]);
    });
  });

  group('decodeRevolutionRange', () {
    test('empty list decodes to full range', () {
      final r = decodeRevolutionRange([]);
      expect(r.min, 0.5);
      expect(r.max, 4.0);
    });

    test('[2.0, 2.5, 3.0] decodes to min 2.0 max 3.0', () {
      final r = decodeRevolutionRange([2.0, 2.5, 3.0]);
      expect(r.min, 2.0);
      expect(r.max, 3.0);
    });

    test('unordered list still decodes correctly', () {
      final r = decodeRevolutionRange([3.0, 0.5, 2.0]);
      expect(r.min, 0.5);
      expect(r.max, 3.0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/revolution_range_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/core/models/revolution_range.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

```dart
const double kRevolutionRangeMin = 0.5;
const double kRevolutionRangeMax = 4.0;
const double kRevolutionRangeStep = 0.5;

/// A full-range selection (kRevolutionRangeMin..kRevolutionRangeMax) encodes
/// to an empty list, matching the existing "empty AllowedRevolutions = no
/// restriction" backend semantics.
List<double> encodeRevolutionRange(double min, double max) {
  if (min <= kRevolutionRangeMin && max >= kRevolutionRangeMax) return [];
  final steps = ((max - min) / kRevolutionRangeStep).round();
  return [
    for (var i = 0; i <= steps; i++)
      ((min + i * kRevolutionRangeStep) * 2).round() / 2,
  ];
}

({double min, double max}) decodeRevolutionRange(List<double> list) {
  if (list.isEmpty) {
    return (min: kRevolutionRangeMin, max: kRevolutionRangeMax);
  }
  var lo = list.first;
  var hi = list.first;
  for (final v in list) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  return (min: lo, max: hi);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/revolution_range_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/models/revolution_range.dart mobile/test/revolution_range_test.dart
git commit -m "$(cat <<'EOF'
Add revolution range encode/decode helpers (mobile)

Dart equivalent of the web helpers — converts a min/max pair to/from the
existing allowedRevolutions list field. Covered by real unit tests since
flutter_test is already wired up for plain (non-widget) tests.
EOF
)"
```

---

### Task 7: Fix mobile's missing `allowedRevolutions` on `GenerateComboOverrides`

**Files:**
- Modify: `mobile/lib/core/models/combo.dart`

`GenerateComboOverrides` (used for the generate/preview quick-overrides payload)
never had this field added, unlike `UserPreference.allowedRevolutions` which
already exists. Fix that gap before wiring the UI in Task 9.

- [ ] **Step 1: Add the field**

Find:
```dart
class GenerateComboOverrides {
  final int? comboLength;
  final int? maxDifficulty;
  final int? strongFootPercentage;
  final int? noTouchPercentage;
  final int? maxConsecutiveNoTouch;
  final bool? includeCrossOver;
  final bool? includeKnee;
  final int? maxHighRevolutionTricks;
  final List<String>? allowedTrickIds;

  const GenerateComboOverrides({
    this.comboLength,
    this.maxDifficulty,
    this.strongFootPercentage,
    this.noTouchPercentage,
    this.maxConsecutiveNoTouch,
    this.includeCrossOver,
    this.includeKnee,
    this.maxHighRevolutionTricks,
    this.allowedTrickIds,
  });

  Map<String, dynamic> toJson() => {
        if (comboLength != null) 'comboLength': comboLength,
        if (maxDifficulty != null) 'maxDifficulty': maxDifficulty,
        if (strongFootPercentage != null) 'strongFootPercentage': strongFootPercentage,
        if (noTouchPercentage != null) 'noTouchPercentage': noTouchPercentage,
        if (maxConsecutiveNoTouch != null) 'maxConsecutiveNoTouch': maxConsecutiveNoTouch,
        if (includeCrossOver != null) 'includeCrossOver': includeCrossOver,
        if (includeKnee != null) 'includeKnee': includeKnee,
        if (maxHighRevolutionTricks != null) 'maxHighRevolutionTricks': maxHighRevolutionTricks,
        if (allowedTrickIds != null && allowedTrickIds!.isNotEmpty) 'allowedTrickIds': allowedTrickIds,
      };
}
```

Replace with:
```dart
class GenerateComboOverrides {
  final int? comboLength;
  final int? maxDifficulty;
  final int? strongFootPercentage;
  final int? noTouchPercentage;
  final int? maxConsecutiveNoTouch;
  final bool? includeCrossOver;
  final bool? includeKnee;
  final int? maxHighRevolutionTricks;
  final List<String>? allowedTrickIds;
  final List<double>? allowedRevolutions;

  const GenerateComboOverrides({
    this.comboLength,
    this.maxDifficulty,
    this.strongFootPercentage,
    this.noTouchPercentage,
    this.maxConsecutiveNoTouch,
    this.includeCrossOver,
    this.includeKnee,
    this.maxHighRevolutionTricks,
    this.allowedTrickIds,
    this.allowedRevolutions,
  });

  Map<String, dynamic> toJson() => {
        if (comboLength != null) 'comboLength': comboLength,
        if (maxDifficulty != null) 'maxDifficulty': maxDifficulty,
        if (strongFootPercentage != null) 'strongFootPercentage': strongFootPercentage,
        if (noTouchPercentage != null) 'noTouchPercentage': noTouchPercentage,
        if (maxConsecutiveNoTouch != null) 'maxConsecutiveNoTouch': maxConsecutiveNoTouch,
        if (includeCrossOver != null) 'includeCrossOver': includeCrossOver,
        if (includeKnee != null) 'includeKnee': includeKnee,
        if (maxHighRevolutionTricks != null) 'maxHighRevolutionTricks': maxHighRevolutionTricks,
        if (allowedTrickIds != null && allowedTrickIds!.isNotEmpty) 'allowedTrickIds': allowedTrickIds,
        if (allowedRevolutions != null && allowedRevolutions!.isNotEmpty) 'allowedRevolutions': allowedRevolutions,
      };
}
```

- [ ] **Step 2: Analyze**

Run: `cd mobile && flutter analyze lib/core/models/combo.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/core/models/combo.dart
git commit -m "$(cat <<'EOF'
Add missing allowedRevolutions field to GenerateComboOverrides (mobile)

UserPreference.allowedRevolutions already existed; the override model used
for one-off generate/preview requests never got the equivalent field, so
it couldn't be sent even via direct API use. Needed before the range-slider
UI (Task 9) can wire it through _preview().
EOF
)"
```

---

### Task 8: Wire into mobile `preferences_screen.dart`

**Files:**
- Modify: `mobile/lib/features/preferences/preferences_screen.dart`

- [ ] **Step 1: Add the import**

Find:
```dart
import '../../core/models/combo.dart';
import '../../core/models/user_preference.dart';
import '../../theme/app_colors.dart';

class PreferencesScreen extends StatefulWidget {
```

Replace with:
```dart
import '../../core/models/combo.dart';
import '../../core/models/revolution_range.dart';
import '../../core/models/user_preference.dart';
import '../../theme/app_colors.dart';

class PreferencesScreen extends StatefulWidget {
```

- [ ] **Step 2: Add the `revRange` summary to `_PrefCard`**

Find:
```dart
  @override
  Widget build(BuildContext context) {
    final flags = '${pref.includeCrossOver ? "Cross-overs" : "No cross-overs"} · '
        '${pref.includeKnee ? "Knee tricks" : "No knee tricks"} · '
        'Max consec. NT ${pref.maxConsecutiveNoTouch}'
        '${pref.maxHighRevolutionTricks != null ? " · Max 3+ rev ${pref.maxHighRevolutionTricks}" : ""}'
        '${pref.allowedTrickIds.isNotEmpty ? " · ${pref.allowedTrickIds.length} allowed tricks" : ""}';
```

Replace with:
```dart
  @override
  Widget build(BuildContext context) {
    final revRange = pref.allowedRevolutions.isNotEmpty
        ? decodeRevolutionRange(pref.allowedRevolutions)
        : null;
    final flags = '${pref.includeCrossOver ? "Cross-overs" : "No cross-overs"} · '
        '${pref.includeKnee ? "Knee tricks" : "No knee tricks"} · '
        'Max consec. NT ${pref.maxConsecutiveNoTouch}'
        '${pref.maxHighRevolutionTricks != null ? " · Max 3+ rev ${pref.maxHighRevolutionTricks}" : ""}'
        '${revRange != null ? " · Revs ${revRange.min.toStringAsFixed(1)}–${revRange.max.toStringAsFixed(1)}" : ""}'
        '${pref.allowedTrickIds.isNotEmpty ? " · ${pref.allowedTrickIds.length} allowed tricks" : ""}';
```

- [ ] **Step 3: Add `_revMin`/`_revMax` state and decode them on load**

Find:
```dart
  bool _includeCrossOver = true;
  bool _includeKnee = true;
  int _maxHighRevTricks = 1;
  List<String> _allowedTrickIds = [];
```

Replace with:
```dart
  bool _includeCrossOver = true;
  bool _includeKnee = true;
  int _maxHighRevTricks = 1;
  double _revMin = kRevolutionRangeMin;
  double _revMax = kRevolutionRangeMax;
  List<String> _allowedTrickIds = [];
```

Find:
```dart
      _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
      _allowedTrickIds = List.from(p.allowedTrickIds);
    }
  }
```

Replace with:
```dart
      _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
      final range = decodeRevolutionRange(p.allowedRevolutions);
      _revMin = range.min;
      _revMax = range.max;
      _allowedTrickIds = List.from(p.allowedTrickIds);
    }
  }
```

- [ ] **Step 4: Send the encoded range on save**

Find:
```dart
        allowedRevolutions: widget.initial?.allowedRevolutions ?? [],
        maxHighRevolutionTricks: _maxHighRevTricks,
```

Replace with:
```dart
        allowedRevolutions: encodeRevolutionRange(_revMin, _revMax),
        maxHighRevolutionTricks: _maxHighRevTricks,
```

- [ ] **Step 5: Add the `_PrefRangeSlider` widget class**

Find:
```dart
class _PrefToggle extends StatelessWidget {
```

Replace with:
```dart
class _PrefRangeSlider extends StatelessWidget {
  final String label;
  final double minValue;
  final double maxValue;
  final double min;
  final double max;
  final double step;
  final void Function(double min, double max) onChanged;

  const _PrefRangeSlider({
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  double _snap(double raw) => (raw / step).round() * step;

  void _handle(Offset local, double width) {
    if (width <= 0) return;
    final pct = (local.dx / width).clamp(0.0, 1.0);
    final snapped = _snap(min + pct * (max - min)).clamp(min, max);
    final distToMin = (snapped - minValue).abs();
    final distToMax = (snapped - maxValue).abs();
    if (distToMin <= distToMax) {
      onChanged(snapped.clamp(min, maxValue), maxValue);
    } else {
      onChanged(minValue, snapped.clamp(minValue, max));
    }
  }

  @override
  Widget build(BuildContext context) {
    final minPct = ((minValue - min) / (max - min)).clamp(0.0, 1.0);
    final maxPct = ((maxValue - min) / (max - min)).clamp(0.0, 1.0);
    final isFullRange = minValue <= min && maxValue >= max;
    final valueLabel = isFullRange
        ? 'All'
        : '${minValue.toStringAsFixed(1)}–${maxValue.toStringAsFixed(1)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            Text(valueLabel, style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.indigo)),
          ],
        ),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTapDown: (d) => _handle(d.localPosition, width),
              onHorizontalDragUpdate: (d) => _handle(d.localPosition, width),
              child: SizedBox(
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 8, left: 0, right: 0,
                      child: Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFE4E3EF), borderRadius: BorderRadius.circular(5))),
                    ),
                    Positioned(
                      top: 8,
                      left: (minPct * width).clamp(0.0, width),
                      child: Container(
                        width: ((maxPct - minPct) * width).clamp(0.0, width),
                        height: 8,
                        decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                    Positioned(
                      left: (minPct * width - 12).clamp(0.0, width - 24 < 0 ? 0.0 : width - 24),
                      top: 0,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: AppColors.indigo, width: 4),
                          boxShadow: const [BoxShadow(color: Color(0x40141221), blurRadius: 8, offset: Offset(0, 3))],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (maxPct * width - 12).clamp(0.0, width - 24 < 0 ? 0.0 : width - 24),
                      top: 0,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: AppColors.indigo, width: 4),
                          boxShadow: const [BoxShadow(color: Color(0x40141221), blurRadius: 8, offset: Offset(0, 3))],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PrefToggle extends StatelessWidget {
```

- [ ] **Step 6: Insert the slider into the form, after "Max 3+ rev tricks"**

Find:
```dart
            _PrefSlider(label: 'Max 3+ rev tricks', value: _maxHighRevTricks.toDouble(), min: 1, max: 15, onChanged: (v) => setState(() => _maxHighRevTricks = v.round())),
            const SizedBox(height: 18),
            _PrefToggle(label: 'Include cross-overs', value: _includeCrossOver, onChanged: (v) => setState(() => _includeCrossOver = v)),
```

Replace with:
```dart
            _PrefSlider(label: 'Max 3+ rev tricks', value: _maxHighRevTricks.toDouble(), min: 1, max: 15, onChanged: (v) => setState(() => _maxHighRevTricks = v.round())),
            const SizedBox(height: 18),
            _PrefRangeSlider(
              label: 'Revolutions',
              minValue: _revMin,
              maxValue: _revMax,
              min: kRevolutionRangeMin,
              max: kRevolutionRangeMax,
              step: kRevolutionRangeStep,
              onChanged: (mn, mx) => setState(() { _revMin = mn; _revMax = mx; }),
            ),
            const SizedBox(height: 18),
            _PrefToggle(label: 'Include cross-overs', value: _includeCrossOver, onChanged: (v) => setState(() => _includeCrossOver = v)),
```

- [ ] **Step 7: Analyze**

Run: `cd mobile && flutter analyze lib/features/preferences/preferences_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/preferences/preferences_screen.dart
git commit -m "$(cat <<'EOF'
Wire revolution range filter into the preference form (mobile)

Adds a hand-rolled _PrefRangeSlider (two-handle sibling of the existing
_PrefSlider, matching the app's custom-painted style rather than
Flutter's Material RangeSlider) and fixes the previously dead
allowedRevolutions passthrough in _save().
EOF
)"
```

---

### Task 9: Wire into mobile `create_combo_screen.dart`

**Files:**
- Modify: `mobile/lib/features/combos/create_combo_screen.dart`

- [ ] **Step 1: Add the import**

Find:
```dart
import '../../core/models/combo.dart';
import '../../core/models/user_preference.dart';
import '../../theme/app_colors.dart';
```

Replace with:
```dart
import '../../core/models/combo.dart';
import '../../core/models/revolution_range.dart';
import '../../core/models/user_preference.dart';
import '../../theme/app_colors.dart';
```

- [ ] **Step 2: Add `_revMin`/`_revMax` state**

Find:
```dart
  int _maxHighRevTricks = 1;
  List<String> _allowedTrickIds = [];
```

Replace with:
```dart
  int _maxHighRevTricks = 1;
  double _revMin = kRevolutionRangeMin;
  double _revMax = kRevolutionRangeMax;
  List<String> _allowedTrickIds = [];
```

- [ ] **Step 3: Reset the range when "Custom" is tapped**

Find:
```dart
                            _maxHighRevTricks = 1;
                            _allowedTrickIds = [];
                          }),
                        ),
```

Replace with:
```dart
                            _maxHighRevTricks = 1;
                            _revMin = kRevolutionRangeMin;
                            _revMax = kRevolutionRangeMax;
                            _allowedTrickIds = [];
                          }),
                        ),
```

- [ ] **Step 4: Copy the range when a saved preset is tapped**

Find:
```dart
                              _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
                              _allowedTrickIds = List.from(p.allowedTrickIds);
                            }),
```

Replace with:
```dart
                              _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
                              final range = decodeRevolutionRange(p.allowedRevolutions);
                              _revMin = range.min;
                              _revMax = range.max;
                              _allowedTrickIds = List.from(p.allowedTrickIds);
                            }),
```

- [ ] **Step 5: Send the encoded range in the preview call**

Find:
```dart
              maxHighRevolutionTricks: _maxHighRevTricks,
              allowedTrickIds: _allowedTrickIds,
            );
```

Replace with:
```dart
              maxHighRevolutionTricks: _maxHighRevTricks,
              allowedTrickIds: _allowedTrickIds,
              allowedRevolutions: encodeRevolutionRange(_revMin, _revMax),
            );
```

- [ ] **Step 6: Add the `_AppRangeSlider` widget class**

Find:
```dart
class _AppSlider extends StatelessWidget {
```

Replace with:
```dart
class _AppRangeSlider extends StatelessWidget {
  final String label;
  final double minValue;
  final double maxValue;
  final double min;
  final double max;
  final double step;
  final void Function(double min, double max)? onChanged;

  const _AppRangeSlider({
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.min,
    required this.max,
    required this.step,
    this.onChanged,
  });

  double _snap(double raw) => (raw / step).round() * step;

  void _handle(Offset local, double width) {
    if (onChanged == null || width <= 0) return;
    final pct = (local.dx / width).clamp(0.0, 1.0);
    final snapped = _snap(min + pct * (max - min)).clamp(min, max);
    final distToMin = (snapped - minValue).abs();
    final distToMax = (snapped - maxValue).abs();
    if (distToMin <= distToMax) {
      onChanged!(snapped.clamp(min, maxValue), maxValue);
    } else {
      onChanged!(minValue, snapped.clamp(minValue, max));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final minPct = ((minValue - min) / (max - min)).clamp(0.0, 1.0);
    final maxPct = ((maxValue - min) / (max - min)).clamp(0.0, 1.0);
    final isFullRange = minValue <= min && maxValue >= max;
    final valueLabel = isFullRange
        ? 'All'
        : '${minValue.toStringAsFixed(1)}–${maxValue.toStringAsFixed(1)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            Text(
              valueLabel,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: enabled ? AppColors.indigo : AppColors.faint),
            ),
          ],
        ),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTapDown: enabled ? (d) => _handle(d.localPosition, width) : null,
              onHorizontalDragUpdate:
                  enabled ? (d) => _handle(d.localPosition, width) : null,
              child: SizedBox(
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE4E3EF),
                            borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: (minPct * width).clamp(0.0, width),
                      child: Container(
                        width: ((maxPct - minPct) * width).clamp(0.0, width),
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: enabled ? AppColors.grad : null,
                          color: enabled ? null : AppColors.line2,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (minPct * width - 12)
                          .clamp(0.0, width - 24 < 0 ? 0.0 : width - 24),
                      top: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                              color: enabled ? AppColors.indigo : AppColors.faint,
                              width: 4),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x40141221),
                                blurRadius: 8,
                                offset: Offset(0, 3))
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (maxPct * width - 12)
                          .clamp(0.0, width - 24 < 0 ? 0.0 : width - 24),
                      top: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                              color: enabled ? AppColors.indigo : AppColors.faint,
                              width: 4),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x40141221),
                                blurRadius: 8,
                                offset: Offset(0, 3))
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AppSlider extends StatelessWidget {
```

- [ ] **Step 7: Insert the slider into the generate view, after "Max 3+ rev tricks"**

Find:
```dart
                _AppSlider(
                  label: 'Max 3+ rev tricks',
                  value: _maxHighRevTricks.toDouble(),
                  min: 1,
                  max: 15,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _maxHighRevTricks = v.round()),
                ),
                const SizedBox(height: 20),
                _ToggleRow(
                  label: 'Include cross-overs',
```

Replace with:
```dart
                _AppSlider(
                  label: 'Max 3+ rev tricks',
                  value: _maxHighRevTricks.toDouble(),
                  min: 1,
                  max: 15,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _maxHighRevTricks = v.round()),
                ),
                const SizedBox(height: 20),
                _AppRangeSlider(
                  label: 'Revolutions',
                  minValue: _revMin,
                  maxValue: _revMax,
                  min: kRevolutionRangeMin,
                  max: kRevolutionRangeMax,
                  step: kRevolutionRangeStep,
                  onChanged: locked
                      ? null
                      : (mn, mx) => setState(() {
                            _revMin = mn;
                            _revMax = mx;
                          }),
                ),
                const SizedBox(height: 20),
                _ToggleRow(
                  label: 'Include cross-overs',
```

- [ ] **Step 8: Analyze**

Run: `cd mobile && flutter analyze lib/features/combos/create_combo_screen.dart`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/features/combos/create_combo_screen.dart
git commit -m "$(cat <<'EOF'
Wire revolution range filter into generate quick-overrides (mobile)

Adds _AppRangeSlider (locked/disabled when a saved preset is selected,
same nullable-onChanged pattern as every other slider on this screen) and
copies/resets the range alongside the other preset-chip fields.
EOF
)"
```

---

### Task 10: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

Per this repo's own convention ("update the relevant section of this file
in the same response" whenever documented behavior changes), document the
new UI next to the existing `MaxHighRevolutionTricks` description.

- [ ] **Step 1: Add the new paragraph**

Find:
```markdown
`MaxHighRevolutionTricks` (`int?`, 1–15, default `1`) caps how many tricks with **3+ revolutions** can appear in one generated/previewed combo — the hardest, rarest moves. No "unlimited" option — always a concrete value in the UI (the field stays nullable server-side only for pre-existing rows saved before this validation range existed). Same field on `UserPreference` and `GenerateComboOverrides` (resolved `Overrides ?? SavedPref ?? null`). Web: number input (min 1, max 15) in both the preference form and the generate-mode custom-overrides panel. Mobile: a plain slider (min 1, max 15, default 1) in both the preference form and generate-mode custom overrides — no separate enable/disable toggle.

`AllowedTrickIds` (`List<Guid>`, default empty) restricts combo generation/preview to only these tricks — an empty list means no restriction (full trick pool).
```

Replace with:
```markdown
`MaxHighRevolutionTricks` (`int?`, 1–15, default `1`) caps how many tricks with **3+ revolutions** can appear in one generated/previewed combo — the hardest, rarest moves. No "unlimited" option — always a concrete value in the UI (the field stays nullable server-side only for pre-existing rows saved before this validation range existed). Same field on `UserPreference` and `GenerateComboOverrides` (resolved `Overrides ?? SavedPref ?? null`). Web: number input (min 1, max 15) in both the preference form and the generate-mode custom-overrides panel. Mobile: a plain slider (min 1, max 15, default 1) in both the preference form and generate-mode custom overrides — no separate enable/disable toggle.

`AllowedRevolutions` (`List<decimal>`, default empty) had existed since the multiple-preferences feature but had no UI anywhere until this feature added one: a min–max range slider (0.5–4.0, 0.5 steps) in both the preference form and the generate-mode custom-overrides panel, on web and mobile, following the same locked-when-preset-selected pattern as every other override field. The UI only ever writes a contiguous range — a full-range selection (0.5–4.0) encodes to an empty list, matching the existing "no restriction" semantics, rather than sending the full explicit 8-value list. Web: `RevRangeSlider` (`web/src/components/ui/rev-range-slider.tsx`), a CSS-only dual native-`<input type="range">` control, with `encodeRevolutionRange`/`decodeRevolutionRange` helpers in `web/src/lib/revolutionRange.ts`. Mobile: `_PrefRangeSlider`/`_AppRangeSlider`, hand-rolled two-handle siblings of the existing single-value `_PrefSlider`/`_AppSlider` (the app never uses Flutter's built-in `RangeSlider`), with the same-shaped helpers in `mobile/lib/core/models/revolution_range.dart`.

`AllowedTrickIds` (`List<Guid>`, default empty) restricts combo generation/preview to only these tricks — an empty list means no restriction (full trick pool).
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
Document the revolution range filter in CLAUDE.md

EOF
)"
```

---

### Task 11: End-to-end manual verification

No automated frontend test suite exists in this repo for full UI flows
(confirmed during planning — no web test runner is configured, and
mobile's `flutter_test` setup has no widget-test coverage for these
screens), so this feature is verified manually, matching how this codebase
already verifies frontend work.

**Files:** none (verification only)

- [ ] **Step 1: Start the API and Postgres**

Run: `docker-compose up -d`
Expected: `postgres` and `api` containers report healthy; `curl -s http://localhost:5050/api/tricks | head -c 200` returns JSON.

- [ ] **Step 2: Web — verify the preference form round-trips a range**

Run: `cd web && npm run dev`

In the browser:
1. Log in, open Preferences, click "New preference."
2. Drag the new "Revolutions" slider to roughly 2.0–3.0, fill in a name, save.
3. Reopen that preference for editing and confirm the slider re-renders at
   ~2.0–3.0 (not the full range) and the card's summary line shows
   `Revs 2.0–3.0`.

Expected: values persist and round-trip correctly.

- [ ] **Step 3: Web — verify generate mode**

In the browser, on the "Generate" tab of Create Combo:
1. Select "Custom," drag the Revolutions slider to 2.0–3.0, click "Generate
   Combo."
2. Confirm every resulting trick's revolution (cross-check the trick names
   against `/tricks`) falls within 2.0–3.0.
3. Select the saved preference from Step 2 and confirm the Revolutions
   slider becomes disabled and shows that preference's own 2.0–3.0 range.

Expected: filtering works and the locked/disabled state matches every other
field on that panel.

- [ ] **Step 4: Web — verify the full-range case sends no restriction**

In the browser, with "Custom" selected, leave the Revolutions slider at its
full 0.5–4.0 extremes and open the browser's Network tab. Trigger "Generate
Combo" and inspect the `/api/combos/generate` request body.

Expected: `overrides.allowedRevolutions` is either absent or an empty array
— not the full 8-value list.

- [ ] **Step 5: Mobile — repeat the same three checks**

Run: `cd mobile && flutter run` (simulator or device, pointed at the local
API per the debug `kBaseUrl` branch)

Repeat Steps 2–4's checks in the mobile app: preset create/edit round-trip,
generate-mode filtering + locked state when a preset is selected, and
full-range = no restriction (inspect via a proxy or by temporarily logging
`overrides.toJson()` in `_preview()` if a network inspector isn't handy).

Expected: same behavior as web.

- [ ] **Step 6: Run the full mobile test suite**

Run: `cd mobile && flutter test`
Expected: all tests pass, including `revolution_range_test.dart` from Task 6.

- [ ] **Step 7: Run the full API test suite (confirm no regression)**

Run: `cd api && dotnet test`
Expected: all 230 existing tests still pass (no backend files were touched
by this feature, so this simply confirms nothing else broke).
