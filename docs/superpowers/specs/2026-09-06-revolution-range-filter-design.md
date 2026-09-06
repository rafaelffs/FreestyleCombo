# Revolution range filter

## Problem

Combo generation already supports filtering the trick pool by revolution
count via `AllowedRevolutions` (`List<decimal>` on `UserPreference` and
`GenerateComboOverrides`) — fully validated (each item `InclusiveBetween(0.5,
4)`) and applied in Step 1 pool filtering
(`if (allowedRevolutions.Count > 0) pool = pool.Where(t =>
allowedRevolutions.Contains(t.Revolution))`). But **no UI anywhere writes to
this field** — every existing row is `[]` (no restriction) today. Users want
to restrict generation to a contiguous band of revolution counts, e.g. "only
2–3 rev tricks," when creating a named preset or when generating/previewing a
combo with custom (unsaved) overrides.

## Non-goals

- No backend, schema, or validator changes. `AllowedRevolutions` already does
  everything needed; this is a frontend-only feature that computes a list
  from a min/max pair and sends it over the existing field.
- No support for a non-contiguous / arbitrary discrete revolution selection
  (e.g. "0.5 and 3.5 but not in between") — only a single contiguous
  min–max range. Nothing in the product today needs more than that, and no
  UI has ever offered arbitrary discrete selection either.
- No change to `MaxHighRevolutionTricks` (the existing "cap on 3+ rev tricks"
  field) or its interaction with this filter — the two remain independent
  and can both apply simultaneously (e.g. range capped to 2–4 *and* a cap of
  1 high-rev trick); if the range's own max excludes 3+ entirely, the cap
  simply has nothing left to act on, which is harmless.

## Data model / encoding

Revolution values only ever fall on 0.5 increments between 0.5 and 4.0 (8
possible values: 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4).

Two small pure helpers (implemented per-platform, no shared package needed
given their size):

- **encode**(min, max) → `List<decimal>` — every 0.5-step value from `min` to
  `max` inclusive. A full-range selection (min=0.5, max=4.0) encodes to an
  **empty list** (matches the existing "no restriction" semantics — do not
  send the full 8-item list, since that's behaviorally identical to `[]` but
  would look like a deliberate restriction if a preset is later inspected via
  the API directly).
- **decode**(`List<decimal>`) → (min, max) — `(0.5, 4.0)` if the list is
  empty; otherwise `(min(list), max(list))`. Since no UI has ever written a
  non-contiguous set, this round-trips correctly for all real data. If a row
  ever did hold a non-contiguous set (only reachable via direct API use), the
  next save from this UI silently normalizes it to the contiguous span
  between its min and max — an accepted, harmless simplification given zero
  such rows exist today.

## Mobile gap to fix first

`mobile/lib/core/models/combo.dart`'s `GenerateComboOverrides` class does
**not** have an `allowedRevolutions` field at all (unlike
`UserPreference.allowedRevolutions`, which exists in
`user_preference.dart` but is currently just passed through unused in
`preferences_screen.dart`'s form — no state variable reads or writes it).
Both need adding:

- `GenerateComboOverrides`: add `final List<double>? allowedRevolutions;`
  constructor param and `toJson()` entry (`if (allowedRevolutions != null &&
  allowedRevolutions!.isNotEmpty) 'allowedRevolutions': allowedRevolutions`,
  matching the existing `allowedTrickIds` non-empty-only pattern).
- `preferences_screen.dart`'s `_PreferenceFormState`: add real
  `_revMin`/`_revMax` state (currently the field is a dead pass-through of
  `widget.initial?.allowedRevolutions`, never surfaced or editable).

Web's `GenerateComboOverrides` (`web/src/lib/api/combos.ts`) already has
`allowedRevolutions?: number[]` — no type change needed there.

## Web changes

**`PreferencesPage.tsx`** (`PreferenceForm`):
- New dual-thumb range control placed directly after the existing "Max 3+
  Rev Tricks" number input (both are revolution-related).
- Implemented as a small new component, e.g. `RevRangeSlider`, using two
  overlaid native `<input type="range" min={0.5} max={4} step={0.5}>`
  elements (a standard CSS-only dual-range trick) — no existing range-slider
  component in the codebase to reuse, and no new npm dependency is
  warranted for one control.
- Label shows the live value, e.g. `Revs: 2.0 – 3.0` (or a "no filter" state
  when spanning the full 0.5–4.0), styled consistently with the numeric
  labels already used for the other fields in this form.
- `PreferenceForm`'s local state stores `allowedRevolutions: number[]`
  exactly as today (the field already exists in `PreferencePayload` and
  `DEFAULTS`); the new control just decodes it to (min, max) for display and
  encodes (min, max) back to a list on every drag update.
- `PreferenceCard`'s read-only summary line gets a short addition when a
  restriction is active, e.g. `· Revs 2.0–3.0`, matching the existing
  `· Max 3+ rev N` / `· N allowed tricks` conditional-append style at
  `PreferencesPage.tsx:264-267`.

**`CreateComboPage.tsx`** (generate mode, "Custom" quick-overrides panel):
- Same `RevRangeSlider` control, placed in the fields grid right after "Max
  3+ Rev Tricks", following the exact existing locked-when-preset-selected
  pattern used by every other field there
  (`value={selectedPref ? selectedPref.allowedRevolutions : overrides.allowedRevolutions}`,
  `disabled={!!selectedPref}` — for a dual-range control this means passing
  `disabled` through to both underlying `<input type="range">` elements).
- `GENERATE_DEFAULTS` gains no new key (an absent/undefined
  `allowedRevolutions` already means "full range, no filter," consistent
  with how `allowedTrickIds` is omitted from this same defaults object
  today).

**i18n**: add a `revRange` key (label "Revolutions") next to the existing
`maxHighRevTricks` key in both the `preferences.*` and `create.*` sections of
`web/src/locales/en.json` and `pt-BR.json`.

## Mobile changes

The app never uses Flutter's built-in `Slider`/`RangeSlider` — every numeric
field uses a hand-rolled, per-file private widget
(`_PrefSlider` in `preferences_screen.dart`, `_AppSlider` in
`create_combo_screen.dart`) built from a `GestureDetector` + `Stack`/`CustomPaint`
matching the app's gradient/JetBrains-Mono visual language. This feature adds
a two-handle sibling of each, rather than pulling in Material's default
`RangeSlider` (which would look inconsistent with every other slider in the
app):

- **`preferences_screen.dart`**: new private `_PrefRangeSlider` widget
  (min/max thumbs, same gesture-handling approach as `_PrefSlider`, snapping
  to 0.5 steps 0.5–4.0), placed after the existing `_PrefSlider(label: 'Max
  3+ rev tricks', ...)` call. `_PreferenceFormState` gets real `_revMin`/
  `_revMax` fields (default 0.5/4.0, or decoded from
  `widget.initial?.allowedRevolutions` — fixing the current dead
  pass-through noted above), and `_save()`'s `UserPreference(...)`
  construction sends `encode(_revMin, _revMax)` instead of the current
  unused passthrough.

- **`create_combo_screen.dart`**: new private `_AppRangeSlider` widget,
  mirroring `_AppSlider`'s exact API shape (`onChanged` nullable = disabled
  when a preset is selected, same as every other field here — no special
  read-only banner needed, since sliders already have a built-in
  disabled/locked visual via `onChanged: null`, unlike the `allowedTrickIds`
  picker button which needed one because it's a different control shape).
  Placed after the existing `_AppSlider(label: 'Max 3+ rev tricks', ...)`
  call. `_comboLength`/etc.'s sibling state gains `_revMin`/`_revMax`,
  reset to `(0.5, 4.0)` in the "Custom" preset-chip `onTap` handler
  alongside the other resets, and decoded from `p.allowedRevolutions` in the
  saved-preset chip's `onTap` handler alongside the other copies. `_preview()`'s
  `GenerateComboOverrides(...)` construction gains
  `allowedRevolutions: encode(_revMin, _revMax)`.

- `preferences_screen.dart`'s preset-card "flags caption" (around line
  177-178: `· Max 3+ rev N` / `· N allowed tricks`, conditionally appended)
  gets the same treatment as web's `PreferenceCard` — append `· Revs
  2.0–3.0` when a restriction is active, using the same `decode()` helper.

## Testing / verification

No backend changes → no new/changed xUnit tests, and the existing 230 stay
valid as-is. This is a UI-only feature with no automated frontend test
suite in this repo (confirmed — `Tests` section of `CLAUDE.md` only covers
API tests), so verification is manual:

1. Web: `npm run dev`, open the Preferences page, create/edit a preset,
   drag the new range control to 2–3, save, reopen the edit form and confirm
   it re-renders at 2–3 (round-trip). Then use "Custom" in Generate mode,
   verify the same control appears unlocked, and verify it's disabled/greyed
   when a saved preset with a range is selected, showing that preset's own
   values.
2. Web: preview/generate a combo with range 2–3 and confirm every resulting
   trick's revolution falls in that band (cross-check against `/tricks`).
3. Mobile: `flutter run`, repeat the same preset-create and generate-Custom
   checks, confirming the new dual-handle slider drags smoothly and snaps to
   0.5 steps, and that switching between "Custom" and a saved preset chip
   correctly copies/resets the range.
4. Edge case: full-range (0.5–4.0) on both platforms must send no
   `allowedRevolutions` restriction (empty list) — confirm via a browser/
   Flutter network inspector that the request body omits/empty-arrays the
   field when the sliders are left at their extremes.

## Docs

`CLAUDE.md`'s "Preferences API" section gets a short addition once this
ships, describing the new range UI the same way `MaxHighRevolutionTricks` is
documented today (which fields/screens expose it, on both web and mobile).
