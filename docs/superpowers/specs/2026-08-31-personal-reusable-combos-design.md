# Personal reusable combos

## Problem

A combo can already be marked "reusable" so it shows up as a selectable
building block (alongside tricks) in `GET /api/tricks` and can be used as a
sub-combo slot in other combos. Today that's entirely admin-gated: only an
admin can flip `Combo.IsReusable`, and only once the combo is already
`Public`.

Owners want a second, lighter path: mark **their own** combo (at any
visibility — Private, PendingReview, or Public) as reusable **for
themselves**, with no admin approval needed. It should show up in the same
reusable-combos list they already see when picking tricks, but private to
them — nobody else sees it there. If the combo is later submitted to public
and an admin decides to make it reusable for everyone, that's the existing,
unchanged admin mechanic.

## Non-goals

- No change to the existing admin `IsReusable` flag, `SetReusableHandler`, or
  its authorization rules.
- No sharing of one user's personal-reusable combos with other specific users
  (only "me" or "everyone via admin approval", nothing in between).
- No reference guard when unsetting personal-reusable (matches the existing
  lenient behavior of the admin flag today).

## Data model

Add `IsPersonalReusable` (`bool`, default `false`) to `Combo`
(`FreestyleCombo.Core/Entities/Combo.cs`). One new migration,
`AddPersonalReusableToCombos`, schema-only.

## API

### New endpoint

`PUT /api/combos/{id}/personal-reusable` — body `{ "isPersonalReusable": bool }`.

- New MediatR slice `SetPersonalReusable` (Command/Handler), modeled on the
  existing `SetReusable` slice.
- **Owner-only** (`combo.OwnerId != userId → 403`, no admin bypass needed —
  admins act on their own combos the same way any owner would). No visibility
  restriction (unlike `SetReusable`, which requires `Public`).
- No reference guard on unsetting — mirrors `SetReusableHandler`'s existing
  behavior of allowing `IsReusable` to be turned off with no check for
  whether other combos reference it as a sub-combo.

### `GET /api/tricks` (`GetTricksHandler`)

Currently returns admin-reusable public combos for everyone. Change:

- `TricksController.GetTricks` resolves `Guid? requestingUserId` the same way
  `CombosController.GetPublic` already does:
  `User.Identity?.IsAuthenticated == true ? Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!) : null`.
- `GetTricksQuery` gains a `Guid? RequestingUserId` field, threaded to
  `IComboRepository.GetReusableAsync(Guid? requestingUserId, ...)`.
- Repository query changes from `WHERE c.IsReusable` to
  `WHERE c.IsReusable OR (c.IsPersonalReusable AND c.OwnerId == requestingUserId)`.
  When `requestingUserId` is null (anonymous), this collapses back to today's
  `WHERE c.IsReusable`.
- Result: everyone still sees all admin-approved public-reusable combos;
  additionally, an authenticated owner also sees their own
  personal-reusable combos merged into the same alphabetically-sorted list,
  regardless of that combo's own visibility. No other user sees them.

### `BuildCombo` / `UpdateCombo` sub-combo slot validation

Both handlers currently reject a sub-combo slot whose target isn't
`IsReusable`. Extend the condition in both
(`BuildComboHandler.cs`, `UpdateComboHandler.cs`) from:

```csharp
if (!sc.IsReusable)
    throw new InvalidOperationException($"Combo {scId} is not reusable.");
```

to:

```csharp
if (!sc.IsReusable && !(sc.IsPersonalReusable && sc.OwnerId == userId))
    throw new InvalidOperationException($"Combo {scId} is not reusable.");
```

The existing flat-only check (`sc.ComboTricks.Any(ct => ct.SubComboId != null)`
→ `"...contains nested sub-combos."`) is unchanged and applies equally to
personal-reusable combos.

### No change needed

- `IComboRepository.IsReferencedAsSubComboAsync` already checks
  `SubComboId == comboId` regardless of which flag made the reference
  possible — the delete guard keeps working as-is.
- All other combo query handlers, delete guards, visibility handlers.

### DTOs

Add `IsPersonalReusable: bool` to every combo response DTO that currently
carries `IsReusable` (`GenerateComboResponse`, `PublicComboDto`, `MyComboDto`,
`ComboDetailDto`), same visibility rules as `IsReusable` today (no
special-casing — it's not sensitive information).

## Mobile UI (Flutter)

Per user decision: **edit screen only**, no card/detail-page icon.

- `mobile/lib/features/combos/combo_detail_screen.dart` — `_EditComboScreen`:
  add a second `SubmitToggle` ("Reusable for me") next to the existing
  "Submit as public" toggle (added in a prior change), gated the same way
  (shown regardless of visibility this time, since personal-reusable has no
  visibility restriction). `_save()` calls the new
  `ApiClient.instance.setPersonalReusable(id, value)` after `updateCombo`,
  mirroring how "Submit as public" calls `setVisibility`.
- `mobile/lib/features/combos/create_combo_screen.dart` — build-tab save
  panel (`_buildComboTab()`): add the same second toggle next to "Submit as
  public", threaded into `_save()`'s `buildCombo(...)` flow followed by a
  `setPersonalReusable` call when checked (build endpoint itself doesn't
  take this flag — same two-call pattern as public submission today).
- `mobile/lib/core/api/api_client.dart`: new `setPersonalReusable(String id,
  bool value)` method, `PUT /combos/{id}/personal-reusable`.
- `mobile/lib/core/models/combo.dart`: `isPersonalReusable` field added to
  `ComboDto` (mirrors `isReusable`).

## Web UI (React)

Same shape, edit screen only:

- `web/src/features/combos/ComboDetailPage.tsx` edit mode: second toggle next
  to "Submit as public".
- `web/src/features/combos/CreateComboPage.tsx` build/save panel: same.
- `web/src/lib/api/combos.ts`: `setPersonalReusable(id, isPersonalReusable)`
  API function; `isPersonalReusable` added to the relevant DTO types.

## Testing

New backend unit tests, following the existing patterns referenced in
`CLAUDE.md` ("reusable combo repository methods", "SetReusable endpoint",
"reusable combo visibility guard"):

- Owner can set/unset `IsPersonalReusable` at any visibility (Private,
  PendingReview, Public).
- Non-owner (including non-admin and admin acting on someone else's combo)
  gets 403.
- `GetTricks`: an authenticated owner's personal-reusable combo appears in
  their own result; does not appear for a different authenticated user or an
  anonymous caller; admin-reusable public combos still appear for everyone
  regardless of auth state.
- `BuildCombo`/`UpdateCombo`: a sub-combo slot referencing the caller's own
  personal-reusable combo succeeds; the same slot from a different
  (non-owner, non-admin-reusable) caller is rejected; nested sub-combos
  inside a personal-reusable combo are still rejected.

## Out of scope for follow-up

If this needs to extend later (e.g. sharing with specific other users, or a
quick-toggle icon on the card), that's a separate design — not part of this
change.
