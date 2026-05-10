# Reusable Combos — Design Spec

**Date:** 2026-05-10  
**Status:** Approved

---

## Overview

Admins can mark any Public combo as **reusable**. Reusable combos appear in the trick picker alongside regular tricks. When a user builds a new combo, they can add a reusable combo as a slot — it displays collapsed (by combo name) and can be expanded to show its individual tricks. Difficulty and trick count are calculated by expanding sub-combo tricks inline.

---

## Constraints

- Only admins can mark a combo reusable.
- A combo must have `Visibility == Public` before it can be marked reusable.
- A reusable combo can only contain regular tricks — no nested sub-combos (flat only).
- A reusable combo cannot be deleted while it is referenced by any other combo (409 Conflict, same pattern as trick delete).
- Editing/renaming a reusable combo is allowed; all references reflect the live name automatically.

---

## Data Model

### `Combo` entity

Add:

```csharp
public bool IsReusable { get; set; } = false;
```

### `ComboTrick` entity

`TrickId` becomes nullable. Add `SubComboId` nullable FK:

```csharp
public Guid? TrickId { get; set; }       // null when slot is a sub-combo
public Guid? SubComboId { get; set; }    // null when slot is a trick
public Combo? SubCombo { get; set; }     // navigation property
```

**Invariant:** exactly one of `TrickId` / `SubComboId` is non-null per row.  
Enforced in application logic (handler validation) and via a DB check constraint in the migration.

### Migration

- `Combos` table: add `IsReusable bool NOT NULL DEFAULT false`
- `ComboTricks` table: make `TrickId` nullable, add `SubComboId uuid NULL REFERENCES Combos(Id)`
- Add check constraint: `CHECK ((TrickId IS NOT NULL AND SubComboId IS NULL) OR (TrickId IS NULL AND SubComboId IS NOT NULL))`

---

## API

### New endpoint — toggle reusable flag

```
PUT /api/combos/{id}/reusable
Auth: Admin
Body: { "isReusable": bool }
```

- Returns 400 if `isReusable: true` and `combo.Visibility != Public`.
- Returns 404 if combo not found.
- Returns 200 with updated combo on success.

### `GET /api/tricks` — unified trick + reusable combo list

Response items gain a `type` discriminator field. Existing trick fields are unchanged.

**Trick item** (unchanged shape, new field):
```json
{
  "type": "trick",
  "id": "...",
  "name": "Around the World",
  "abbreviation": "ATW",
  ...
}
```

**Combo item** (new):
```json
{
  "type": "combo",
  "id": "...",
  "name": "Basic Foundation",
  "averageDifficulty": 3.5,
  "trickCount": 4,
  "tricks": [
    { "trickId": "...", "name": "ATW", "abbreviation": "ATW", "position": 1, ... }
  ]
}
```

Handler: after fetching tricks normally (applying existing filters), also fetches `Combos WHERE IsReusable = true` — reusable combos are returned unconditionally regardless of the `crossOver`, `knee`, or `maxDifficulty` filter params, since those are trick properties. The combined list is returned sorted: tricks first (alphabetical), then combos (alphabetical).

### `BuildComboCommand` / `BuildComboTrickItem`

`BuildComboTrickItem` gains optional `subComboId`:

```csharp
public record BuildComboTrickItem(
    Guid? TrickId,
    Guid? SubComboId,
    int Position,
    bool StrongFoot,
    bool NoTouch
);
```

Handler validation: each item must have exactly one of `TrickId` / `SubComboId` non-null.

When a slot has `SubComboId`:
- Load the referenced combo; verify it exists and `IsReusable == true`.
- Verify it contains no sub-combo slots itself (flat constraint).
- Expand its tricks for `TrickCount` and `AverageDifficulty` calculation (all tricks, including sub-combo tricks, are counted).
- Store a single `ComboTrick` row with `SubComboId` set and `TrickId` null.

`StrongFoot` and `NoTouch` on a sub-combo slot are ignored (stored as `false`).

### `ComboTrickDto` — updated shape

```csharp
public class ComboTrickDto
{
    public string Type { get; set; } = "trick";  // "trick" | "combo"

    // Trick fields (populated when Type == "trick")
    public Guid? TrickId { get; set; }
    public string? Name { get; set; }
    public string? Abbreviation { get; set; }
    public int Position { get; set; }
    public bool StrongFoot { get; set; }
    public bool NoTouch { get; set; }
    public int Difficulty { get; set; }
    public decimal Revolution { get; set; }
    public bool CrossOver { get; set; }
    public bool IsTransition { get; set; }

    // Sub-combo fields (populated when Type == "combo")
    public Guid? SubComboId { get; set; }
    public string? SubComboName { get; set; }
    public List<ComboTrickDto>? SubComboTricks { get; set; }
}
```

All combo query handlers (`GetCombo`, `GetMyCombos`, `GetPublicCombos`, `GetPendingComboReviews`) must eager-load `ComboTricks.SubCombo.ComboTricks.Trick` to populate sub-combo data.

### `DELETE /api/combos/{id}` — guard

Before deleting, check if any `ComboTrick` rows reference `SubComboId == id`. If yes, return 409 Conflict: `"This combo is used as a sub-combo in X combo(s) and cannot be deleted."`.

### `UpdateCombo` — flat constraint

When updating a reusable combo's trick list, validate that no slot references a `SubComboId` (reusable combos must stay flat).

---

## Display Text

`DisplayText` for a combo with sub-combo slots is built by expanding sub-combo tricks inline:

```
ATW [BasicFoundation: ATW CRO STA] CRO
```

The sub-combo block is wrapped in brackets with the combo name prefix, so it's human-readable in text form.

---

## Web UI

### `/tricks` page

- The tricks table gains a new row type for reusable combos (distinct background, e.g. indigo-50 tint, with a "combo" badge in the Name column).
- Clicking a combo row toggles an inline expansion showing the list of its tricks.
- Admin users see a "Reusable" column with a toggle switch on each combo row. Toggling calls `PUT /api/combos/{id}/reusable`.
- Non-admin users see combo rows but no toggle.

### `CreateComboPage` — build mode trick picker

- The search/picker list shows both tricks and reusable combos.
- Combo items display: bold name + `(combo · N tricks · avg diff X)`.
- Adding a combo item appends a single collapsed slot to the combo builder.
- The slot shows: combo name + trick count + a chevron expand button.
- Expanding shows the individual tricks inside (read-only, no drag or edit).
- The difficulty summary and trick count in the header expand sub-combo tricks.

### Combo detail page

- `ComboTrickDto` items with `type: "combo"` render as a collapsible group.
- Collapsed: shows combo name + trick count.
- Expanded: shows individual tricks in the sub-combo.

### Admin — reusable combo management

- On the Approvals page (or a dedicated section), Public combos have a "Reusable" toggle in the action row.
- Admins can flip it on/off. The UI optimistically updates and reverts on error.

---

## Mobile UI

Mirrors the web design:

- Tricks screen: reusable combos appear in the list with a distinct chip; tapping expands inline.
- Admin column visible only to admin users.
- Build combo screen: picker includes combo items; tapping one adds a collapsed slot; slot has an expand/collapse arrow.
- Combo detail screen: sub-combo slots render as a collapsible `ExpansionTile`.

---

## Validation Summary

| Rule | Where enforced |
|---|---|
| Exactly one of TrickId/SubComboId per slot | Handler + DB check constraint |
| SubComboId must reference an IsReusable combo | Handler |
| Reusable combo must be Public | `PUT /reusable` endpoint |
| Reusable combos cannot contain sub-combo slots | BuildCombo + UpdateCombo handlers |
| Delete blocked if referenced as sub-combo | DeleteCombo handler |
| Admin only for IsReusable toggle | `[Authorize(Roles = "Admin")]` |

---

## Out of Scope

- Nested sub-combos (a reusable combo containing another reusable combo).
- Reusable combos visible to non-Public status.
- Generating combos (AI flow) with sub-combo slots — generate only picks individual tricks.
- Sub-combo slots in the Preview endpoint — preview only works with individual tricks. Passing `subComboId` in `PreviewComboCommand` or `GenerateComboCommand` returns 400.
- Updating a regular combo to include sub-combo slots is fully supported via `UpdateComboCommand`. Only reusable combos themselves are blocked from containing sub-combo slots.
