# Optional preference fields, reorder, and knee-tricks default

## Problem

The preference form and the generate screen's "Custom" quick-overrides panel
currently force a user to accept a concrete value for every numeric field
(combo length, max difficulty, no-touch %, max consecutive no-touch, max 3+
rev tricks, and the just-added revolution range) — there's no way to say "I
don't care about this one." Additionally the field order buries the two
fields users most want to set first (allowed tricks, revolution range) near
the bottom, and the default "Include knee tricks" state doesn't match what
most users actually want.

This feature: (1) makes those six fields individually toggleable — off means
"don't restrict on this," not a specific number, (2) reorders fields on both
the preference form and the generate screen so the highest-value fields come
first, (3) flips `IncludeKnee`'s default from on to off. Applies to both web
and mobile, on both the preference form and the generate-mode "Custom" panel
— confirmed with the user as in-scope for all four surfaces.

## Non-goals

- No change to `StrongFootPercentage`, `IncludeCrossOver` — not in the
  requested toggle list, stay mandatory/as-is.
- No new copy/i18n strings on web — a checkbox next to an existing label
  needs no new translated text.
- No change to how `AllowedTrickIds` itself works (already optional via
  empty-list semantics with its own picker UI) — it only gets repositioned,
  not converted to a toggle.

## Backend scope is smaller than it looks

`GenerateComboOverrides` (`api/FreestyleCombo.API/Features/Combos/GenerateCombo/GenerateComboCommand.cs`)
— the model used by the generate/preview "Custom" panel — **already has every
one of these six fields as nullable** (`int? ComboLength`, `int? MaxDifficulty`,
`int? NoTouchPercentage`, `int? MaxConsecutiveNoTouch`, `int? MaxHighRevolutionTricks`,
`List<decimal>? AllowedRevolutions`), already validated with `.When(HasValue)`
guards, and both `GenerateComboHandler`/`PreviewComboHandler` already resolve
via `Overrides?.X ?? SavedPref?.X ?? <default>` (or, for `MaxHighRevolutionTricks`/
`AllowedRevolutions`, resolve straight to "no restriction" when absent — no
hardcoded fallback). **The generate screen needs zero backend changes.**

The gap is entirely on `UserPreference` (the saved-preset entity), where
`ComboLength`, `MaxDifficulty`, `NoTouchPercentage`, `MaxConsecutiveNoTouch`
are plain non-nullable `int` columns — a saved preference is currently
forced to have a concrete value for all four. (`MaxHighRevolutionTricks` and
`AllowedRevolutions` are already nullable/empty-capable there too — no
change needed for those two either.) So the actual schema/validator work is:

- `UserPreference.cs`: change `MaxDifficulty`, `ComboLength`,
  `NoTouchPercentage`, `MaxConsecutiveNoTouch` from `int` to `int?` (drop
  their `= <default>` initializers, matching how `MaxHighRevolutionTricks`
  is already declared with no initializer).
- One migration, `MakePreferenceFieldsOptional`, `ALTER COLUMN ... DROP NOT
  NULL` on those four columns (schema-only, no data loss — existing rows
  keep their current values).
- `CreatePreferenceCommand`/`UpdatePreferencesCommand`/`PreferenceDto` (in
  `GetPreferences/GetPreferencesQuery.cs`): same four fields become `int?`.
- `CreatePreferenceValidator`/`UpdatePreferencesValidator`: their
  `InclusiveBetween` rules for these four fields gain
  `.When(x => x.Field.HasValue)`, matching the existing
  `MaxHighRevolutionTricks` rule exactly.
- `CreatePreferenceHandler`/`UpdatePreferencesHandler`: no logic changes —
  straight assignment already works once both sides are `int?`.
- `GenerateComboHandler.cs`/`PreviewComboHandler.cs`: no changes to the
  resolution lines — `savedPref?.MaxDifficulty ?? 10` etc. already handles a
  null field correctly once the property itself is nullable.

**`MaxHighRevolutionTricks` and `AllowedRevolutions` need zero backend
changes anywhere** (entity, DTOs, validators, generation) — they're already
fully nullable/empty-capable on both `UserPreference` and
`GenerateComboOverrides`. Enabling their toggle is a pure UI change: remove
the "always send a concrete value" constraint from the frontend and let the
toggle drive whether a value or `null`/`[]` is sent.

## `IncludeKnee` default flip

Change the literal default from `true` to `false` in:
- `UserPreference.cs`'s property initializer (`= true` → `= false`) —
  cosmetic only, since `Create`/`UpdatePreferenceHandler` always assign it
  explicitly from the request.
- `GenerateComboHandler.cs`/`PreviewComboHandler.cs`'s resolution line
  (`?? true` → `?? false`) — the actual behavior change, for the rare case
  where no override and no saved preference supply a value.
- Every frontend "new preference" / "new Custom generate" initial-state
  default (web `DEFAULTS`/`GENERATE_DEFAULTS`, mobile's
  `_includeKnee` field initializer and the "Custom" preset-chip reset
  handler) — the actual user-facing behavior change.

No schema/migration change — `IncludeKnee` stays a plain non-nullable
`bool`, only its default literal changes.

## Field order (both the preference form and generate-mode "Custom" panel, both platforms)

1. Name
2. **Allowed tricks** (moved here from the bottom — "one of the first things
   a user can set")
3. Combo length — **toggleable**
4. **Revolutions** (moved here from after Max 3+ rev tricks) — toggleable
5. Strong foot — unchanged, not toggleable
6. No-touch — toggleable
7. Max consecutive no-touch — toggleable
8. Max 3+ rev tricks — toggleable
9. **Max difficulty** (moved here — to Revolutions' old slot) — toggleable
10. Include cross-overs (unchanged)
11. Include knee tricks (unchanged control, new default: off)

On mobile's generate screen, "Allowed tricks" already exists there (a picker
row) and moves the same way. On web's generate screen, "Allowed tricks" does
not currently exist at all (a pre-existing, documented gap — CLAUDE.md:
"not currently exposed in the web generate-mode quick-overrides panel") —
this feature does **not** add it there; nothing to move.

## Toggle semantics

Toggle off = the field's value is `null` (or `[]` for Revolutions) in the
outgoing request — not a specific number. Toggle on = the field's current
slider/input value is sent. The component's local state model:

- Each of the six fields keeps its slider's underlying numeric value in
  local state **at all times** (so switching a toggle off and back on
  within the same editing session doesn't lose whatever the user had
  dragged to) — a plain `boolean enabled` flag lives alongside it, and the
  payload sent to the API is computed at submit/preview time as
  `enabled ? value : null` (or `enabled ? encodeRevolutionRange(min,max) :
  []` for Revolutions).
- Loading an existing saved preference: `enabled = (field !== null)`; the
  slider's local value is the loaded value if present, otherwise the
  field's existing hardcoded UI default (6 / 10 / 30 / 2 / 1) so the slider
  has something sane to show if the user re-enables it.
- New preference / fresh "Custom" selection: all six toggles default **on**
  (matches today's out-of-the-box behavior — nothing changes for a user who
  never touches a toggle), using the same hardcoded UI defaults as today.

## Generate screen's locked/preset-selected state

The generate screen already has a "locked" mode when a saved preference is
selected (every field becomes read-only, showing that preference's own
values, editable only under "Custom" — see `CreateComboPage.tsx`'s
`selectedPref ? ... : overrides...` / `disabled={!!selectedPref}` pattern,
and mobile's nullable `onChanged` convention on `_AppSlider`/`_AppRangeSlider`).
The new toggle checkbox is part of that same locked surface: when a preset
is selected, the checkbox reflects whether the *preset's* value is null
(checked = preset has a concrete value, unchecked = preset field is null)
and is itself disabled (`disabled={!!selectedPref}` on web,
`onChanged: null` passed to the toggle on mobile) — the user can't flip it
without first switching to "Custom," consistent with every other field on
this panel.

## UI implementation

**Web**: new shared `OptionalField` component
(`web/src/components/ui/optional-field.tsx`) — takes `{ label, enabled,
onToggle, disabled?, children }`, renders the label with a checkbox to its
right, and renders `children` (the existing `<Input>`/`<RevRangeSlider>`)
only when `enabled`. Wraps all six fields identically in both
`PreferenceForm` (`PreferencesPage.tsx`) and the quick-overrides grid
(`CreateComboPage.tsx`) — replacing their current bare `<div><Label/>
<Input/></div>` wrappers. No new i18n keys needed (existing `t('preferences.X')`/
`t('create.X')` label calls are reused as the `label` prop).

**Mobile**: a new private `_OptionalField` widget, duplicated in both
`preferences_screen.dart` and `create_combo_screen.dart` (matching this
codebase's existing convention of per-file private widgets rather than a
shared one — same reasoning as `_PrefSlider`/`_AppSlider` already being
separate). Takes `{label, enabled, onChanged(bool), child}`, renders a row
with the label and a `CupertinoSwitch` (matching `_PrefToggle`'s existing
switch style), and the passed-in slider widget only when `enabled`.

## Testing / verification

Backend: new xUnit tests for `CreatePreferenceHandler`/`UpdatePreferencesHandler`
saving a preference with these four fields `null`, and for
`GenerateComboHandler`/`PreviewComboHandler` resolving a `null` saved-preference
field to its documented hardcoded default. Existing 230 tests must still
pass unmodified (no behavior change for any preference that already has
concrete values, which is every pre-existing row).

Frontend: no automated test suite exists for these UI flows (consistent
with the rest of this codebase) — manual verification: create a preference
with several toggles off, save, reload the edit form and confirm the
toggles are off and their sliders hidden; generate a combo with a field
toggled off and confirm the request omits it; flip a toggle back on and
confirm the slider reappears with a sane value.

## Docs

`CLAUDE.md`'s "Preferences API" section needs updates to: document the new
nullable columns + migration, describe the toggle UI pattern (mirroring how
`MaxHighRevolutionTricks`/`AllowedRevolutions` are documented today), update
the field-order description, note the `IncludeKnee` default flip, and
**remove** the now-stale "No 'unlimited' option — always a concrete value
in the UI" line for `MaxHighRevolutionTricks` (superseded by this feature —
it's toggleable/nullable via the UI now, same as every other field here).
