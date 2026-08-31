# FreestyleCombo — Project Context for Claude

> **Claude instruction:** Whenever you make a change that affects documented behavior (validation limits, architecture, APIs, design decisions, test count, environment variables, etc.), update the relevant section of this file in the same response before finishing.

A full-stack freestyle football combo generator.  
Users register/login, generate combos (with AI descriptions via Claude), rate each other's public combos, and save preferences. A Hangfire background job weekly adjusts trick `CommonLevel` weights based on aggregate ratings.

---

## Architecture

```
FreestyleCombo/
├── api/                          # ASP.NET Core 10, Vertical Slice, .NET 9
│   ├── FreestyleCombo.Core/      # Entities, Interfaces, Result<T>
│   ├── FreestyleCombo.Infrastructure/  # EF Core, Repositories, Seeder, Migrations
│   ├── FreestyleCombo.AI/        # Anthropic SDK (ComboEnhancerService), Hangfire job
│   ├── FreestyleCombo.API/       # MediatR Vertical Slices, Controllers, Program.cs
│   └── FreestyleCombo.Tests/     # xUnit + FluentAssertions + Moq
├── web/                          # React 19, Vite, TypeScript, Tailwind v4, TanStack Query
├── mobile/                       # Flutter (Dart), go_router, dio, shared_preferences
├── docker-compose.yml            # postgres:16, api (host port 5050)
└── .github/workflows/ci.yml      # Runs on push to main/feature/**
```

---

## API — Key Details

### Tech stack
- **ASP.NET Core 10** · **MediatR** · **FluentValidation** (pipeline behavior) · **EF Core + Npgsql** · **ASP.NET Core Identity** (IdentityUser<Guid>) · **JWT Bearer** · **Hangfire + Hangfire.PostgreSql** · **Anthropic.SDK 5.10.0** · **Swashbuckle 10** / **Microsoft.OpenApi 2.0**

### Entities (`FreestyleCombo.Core/Entities/`)
| Entity | Key fields |
|---|---|
| `AppUser` | `IdentityUser<Guid>`, has `ICollection<Combo>`, `ICollection<ComboRating>`, `ICollection<UserPreference>`, `ICollection<TrickSubmission>`, `ICollection<UserFavouriteCombo>`, `ICollection<UserComboCompletion>` |
| `Trick` | `Id, Name, Abbreviation, CrossOver, Knee, Revolution(decimal), Difficulty, CommonLevel` |
| `Combo` | `Id, OwnerId, Name?, AverageDifficulty, TrickCount, Visibility(ComboVisibility), IsReusable(bool), CreatedAt, AiDescription, ICollection<UserFavouriteCombo>`, `ICollection<UserComboCompletion>`, `ICollection<UserPersonalReusableCombo>` — `IsPublic` is a computed property (`=> Visibility == ComboVisibility.Public`), ignored by EF. `IsReusable` can only be set by admins; combo must be Public first. Reusable combos cannot be set to non-public (blocked in UpdateCombo, UpdateVisibility, and RejectComboVisibility — owner edits to a reusable public combo skip the PendingReview reset). Personal-reusable is **not** a field on `Combo` — see `UserPersonalReusableCombo` below and "Personal reusable combos". |
| `UserPersonalReusableCombo` | Composite PK `(UserId, ComboId)`, `CreatedAt` — cascade deletes on both FK, same shape as `UserFavouriteCombo`. One row = one user has added one combo (their own, at any visibility, or anyone's Public one) to their own personal trick-building list. |
| `ComboTrick` | `Id, ComboId, TrickId?(nullable), SubComboId?(nullable), Position, StrongFoot, NoTouch` — exactly one of TrickId/SubComboId must be non-null (DB check constraint `CK_ComboTrick_TrickOrSubCombo`). SubComboId references a reusable combo. |
| `ComboRating` | `Id, ComboId, RatedByUserId, Score, CreatedAt` |
| `UserPreference` | `Id, UserId, Name(string max 100), MaxDifficulty, ComboLength, StrongFootPercentage, NoTouchPercentage, MaxConsecutiveNoTouch, IncludeCrossOver, IncludeKnee, AllowedRevolutions(List<decimal>), MaxHighRevolutionTricks(int?), AllowedTrickIds(List<Guid>)` — 1:many with AppUser (no unique index on UserId), `AllowedRevolutions` and `AllowedTrickIds` stored as `jsonb` |
| `TrickSubmission` | `Id, Name, Abbreviation, CrossOver, Knee, Revolution, Difficulty, CommonLevel, Status(enum), SubmittedAt, SubmittedById, ReviewedAt?, ReviewedById?` |
| `UserFavouriteCombo` | Composite PK `(UserId, ComboId)`, `CreatedAt` — cascade deletes on both FK |
| `UserComboCompletion` | Composite PK `(UserId, ComboId)`, `CreatedAt` — cascade deletes on both FK. Tracks which users have marked a combo as done (toggle). |

`SubmissionStatus` enum: `Pending = 0`, `Approved = 1`, `Rejected = 2` — stored as int.  
Approving a submission creates a real `Trick` from the submission fields.

`ComboVisibility` enum (in `FreestyleCombo.Core/Entities/Combo.cs`): `Private = 0`, `PendingReview = 1`, `Public = 2` — stored as int column `Visibility` in `Combos` table (default 0). When a user sets a combo public (build or update), it goes to `PendingReview`; an admin approves/rejects it.

### Interfaces (`FreestyleCombo.Core/Interfaces/`)
- `ITrickRepository` (includes `DeleteAsync` — checks ComboTricks before deleting)
- `IComboRepository` (includes `DeleteAsync`, `GetAllByOwnerAsync`, `GetReusableAsync`, `IsReferencedAsSubComboAsync` — all query methods eager-load `ComboTricks.SubCombo.ComboTricks.Trick`)
- `IComboRatingRepository`, `ITrickSubmissionRepository`
- `IUserPreferenceRepository` — `GetAllByUserIdAsync`, `GetByIdAsync`, `AddAsync`, `UpdateAsync`, `DeleteAsync`
- `IUserFavouriteRepository` — `AddAsync`, `RemoveAsync`, `GetFavouriteComboIdsAsync`, `ExistsAsync`
- `IUserComboCompletionRepository` — `AddAsync`, `RemoveAsync`, `GetCompletedComboIdsAsync`, `ExistsAsync`, `GetCompletionCountsAsync`
- `IUserPersonalReusableComboRepository` — `AddAsync`, `RemoveAsync`, `GetComboIdsAsync`, `ExistsAsync` — same shape as `IUserFavouriteRepository`
- `IComboEnhancerService` — extracted for Moq mockability

### Tricks API (`/api/tricks`)
| Method | Route | Auth | Description |
|---|---|---|---|
| `GET` | `/` | Public (optionally authed) | Returns `TrickListItemDto[]` — both tricks (`type: "trick"`) and reusable combos (`type: "combo"`). Tricks sorted alphabetically first, then combos alphabetically (by `Name ?? DisplayText`). Trick filters don't affect combos. The "combo" set is every admin-`IsReusable` public combo (everyone sees these) **plus**, for an authenticated caller, every combo they've personally added to their own trick list (`UserPersonalReusableCombo`) — see "Personal reusable combos" below. A combo entry's `Name` can be `null` (combo names are optional) — `TrickListItemDto` also carries a `DisplayText` abbreviation-notation fallback (same pattern as `PublicComboDto`/`ComboDetailDto`/etc.) for clients to fall back to; both web (`comboDisplayName()`) and mobile (`ComboItem.displayName`) must use the fallback rather than reading `name` directly — an earlier version didn't, and unmarshalling a null name into a non-nullable field crashed the Generate-combo screen. |
| `PUT` | `/{id}` | Admin | Update trick — all fields editable |
| `DELETE` | `/{id}` | Admin | Delete trick — 409 Conflict if used in any combo |

Trick delete throws `InvalidOperationException` ("This trick is used in X combo(s)...") if any `ComboTrick` references it → middleware returns 400.

### Combos extra endpoints
| Method | Route | Auth | Description |
|---|---|---|---|
| `POST` | `/api/combos/preview` | User | Preview combo (no save, no AI) — returns `PreviewComboResponse { Tricks, Warnings }` |
| `POST` | `/api/combos/build` | User | Build combo manually — accepts optional `name`; no AI description (`AiDescription = null`); sets `Visibility = PendingReview` if `isPublic = true` |
| `PUT` | `/api/combos/{id}` | User/Admin | Update combo (name + tricks) — owner or admin only; if combo was `Public`, resets to `PendingReview` |
| `DELETE` | `/api/combos/{id}` | User/Admin | Owner or Admin can delete; 403 otherwise. 409 Conflict if combo is referenced as a sub-combo in another combo. |
| `PUT` | `/api/combos/{id}/reusable` | Admin | Toggle `IsReusable` flag — 400 if setting true on non-Public combo. Body: `{ "isReusable": bool }` |
| `POST` | `/api/combos/{id}/personal-reusable` | User | Add a combo to the caller's own personal trick list — allowed for the combo's owner at any visibility, or for anyone if the combo is `Public`; 403 for a non-owner on a non-public combo. |
| `DELETE` | `/api/combos/{id}/personal-reusable` | User | Remove a combo from the caller's own personal trick list (idempotent, no ownership check needed — you're only ever removing your own list entry). |
| `POST` | `/api/combos/{id}/favourite` | User | Add combo to favourites |
| `DELETE` | `/api/combos/{id}/favourite` | User | Remove combo from favourites |
| `POST` | `/api/combos/{id}/complete` | User | Mark combo as done (idempotent) |
| `DELETE` | `/api/combos/{id}/complete` | User | Unmark combo as done (idempotent) |
| `GET` | `/api/combos/pending-review` | Admin | List combos pending admin review |
| `POST` | `/api/combos/{id}/approve-visibility` | Admin | Approve → sets `Visibility = Public` |
| `POST` | `/api/combos/{id}/reject-visibility` | Admin | Reject → sets `Visibility = Private` |

`BuildComboCommand` / `UpdateComboCommand` validate: `Tricks` NotEmpty, each `Position >= 1`, NoTouch only on `CrossOver = true` tricks. Each slot must have exactly one of `TrickId`/`SubComboId` (XOR). Sub-combo slots must reference a reusable combo with no nested sub-combos (flat only) — "reusable" here means `IsReusable` **or** the caller has personally added that combo to their own list (`IUserPersonalReusableComboRepository.ExistsAsync(userId, subComboId)`). Reusable combos cannot themselves have sub-combo slots. `BuildComboTrickItem(Guid? TrickId, Guid? SubComboId, int Position, bool StrongFoot, bool NoTouch)`.

`ComboTrickDto` is a discriminated union: `Type = "trick"` (trick fields) or `Type = "combo"` (SubComboId, SubComboName, SubComboTricks). All combo response DTOs include `IsReusable: bool` and `IsPersonalReusable: bool` — the latter is computed per-requesting-user (like `IsFavourited`/`IsCompleted`) in `GetPublicCombos`/`GetMyCombos`/`GetCombo`/`GetFavouritedCombos`; the single-action responses (`BuildCombo`, `UpdateCombo`, `GenerateCombo`, `SetReusable`) leave it at the DTO default `false`, matching how those same handlers already treat `IsFavourited`/`IsCompleted`.

#### Personal reusable combos

A lighter, per-user alternative to the admin-gated `IsReusable`: **any** user can add **any** combo to their own personal trick-building list via `UserPersonalReusableCombo` (a join table, not a flag on `Combo` — a single bool couldn't represent "Alice and Bob each independently bookmarked someone else's public combo"). Who can add what: the owner can add their own combo at any visibility (Private/PendingReview/Public); a non-owner can only add a combo that's already `Public`, unless they're an admin — admins bypass the visibility check entirely, same as every other elevated combo permission in this codebase (`AddPersonalReusableHandler` injects `IHttpContextAccessor` and checks `IsInRole("Admin")`). Once added, that combo becomes selectable as a sub-combo/reusable block **only in that adder's own** `GET /api/tricks` result and sub-combo slot validation — nobody else sees it there just because someone else added it. The existing admin `IsReusable` mechanic (Public-only, admin-only, visible to everyone) is completely unchanged and independent of this.

`IComboRepository.GetReusableAsync(Guid? requestingUserId, ...)` implements the merge (`WHERE IsReusable OR EXISTS (SELECT 1 FROM UserPersonalReusableCombos WHERE ComboId = c.Id AND UserId = requestingUserId)`); `TricksController.GetTricks` resolves `requestingUserId` from the JWT when present, same pattern as `CombosController.GetPublic`. Mobile/web UI: an instant "list in trick list" link-icon toggle sits next to the favourite icon (combo detail hero, and every combo card in the list — owner-only, or non-owner when the combo is `Public`), each firing a confirm sheet/dialog before calling the add/remove endpoint; a "List combo in the trick list" checkbox is also present in the manual build-save panel and the post-save edit screen (owner-only there, since those screens only ever act on your own combo). See `docs/superpowers/specs/2026-08-31-personal-reusable-combos-design.md` for the original design (note: that doc's "owner-only" authorization was later corrected to the owner-or-public rule described here, and the `Combo.IsPersonalReusable` bool it specifies was replaced by the `UserPersonalReusableCombo` relation — this section is the current source of truth).

`GenerateComboCommand(Guid? PreferenceId, GenerateComboOverrides? Overrides, string? Name)` — `PreferenceId` replaces the old `UsePreferences` bool. When set, the handler fetches that preference by ID and verifies ownership; when null, uses inline `Overrides`. Saved as `null` if Name is blank/whitespace. **No longer generates an AI description** — `AiDescription` is always `null` for new combos.

`PreviewComboCommand(Guid? PreferenceId, GenerateComboOverrides? Overrides)` — runs generation steps 1–5 (filter, split, pick, shuffle, annotate NoTouch). **No AI call, no DB save.** Same `PreferenceId` pattern as GenerateComboCommand.

`UpdateComboCommand(Guid ComboId, string? Name, List<BuildComboTrickItem>? Tricks)` — updates Name and/or replaces trick list. Throws `UnauthorizedAccessException` (→ 403) if caller is not owner or admin.

All combo DTOs (`GenerateComboResponse`, `PublicComboDto`, `MyComboDto`, `ComboDetailDto`) now include `Name?`, `OwnerUserName?`, `IsFavourited`, `IsCompleted`, `CompletionCount`, `Visibility` (string: "Private"/"PendingReview"/"Public"). Combos in `GET /mine` sort favourites first, then by `CreatedAt DESC`.

`GET /api/combos/public` filters by `Visibility == Public` (not `IsPublic`). `UpdatePreferencesHandler` now returns `PreferenceDto` (was `Ok()` with no body).

### Login with username or email
`LoginCommand` field renamed `Email` → `Credential`. Handler tries `FindByEmailAsync` first, then `FindByNameAsync`. Validator uses `NotEmpty` + `MaximumLength(256)` only (no `EmailAddress()` rule).

### Forgot / reset password
`AppUser` has `PasswordResetCodeHash` (string?) and `PasswordResetCodeExpiresAt` (DateTime?) — a short-lived, SHA-256-hashed 6-digit numeric code, not an ASP.NET Identity token (chosen so the same flow works on mobile without deep-linking).
- `POST /api/auth/forgot-password { email }` — always 204, never reveals whether the email exists. If a user matches, generates a 6-digit code, hashes it, sets a 15-minute expiry, and emails it via `IEmailService`.
- `POST /api/auth/reset-password { email, code, newPassword }` — validates the code (hash match + not expired), then `RemovePasswordAsync` + `AddPasswordAsync`, then clears the code fields. 400 on any mismatch/expiry (`InvalidOperationException` → error middleware).
- `IEmailService` / `ResendEmailService` live in `FreestyleCombo.AI/Services/` (same pattern as `IComboEnhancerService`) — POSTs to the Resend REST API directly (no SDK dependency). If `Resend:ApiKey` isn't configured, it logs a warning and no-ops instead of throwing — forgot-password still returns 204, the code is just never delivered. `Resend:FromAddress` defaults to `FreestyleCombo <onboarding@resend.dev>`.
- Web: `/forgot-password` (`ForgotPasswordPage`, two-step: request code → enter code + new password), linked from `LoginPage`. Mobile: `/forgot-password` (`ForgotPasswordScreen`, same two-step flow via `AuthScaffold`), linked from `LoginScreen`.

### Google & Apple Sign-In
`AppUser` has `AuthProvider` (string?, `"google"` | `"apple"` | null) and `ExternalSubject` (string?, the provider's `sub` claim) — null/null for password-only accounts. No separate external-logins table; one row per user, `PasswordHash` stays null for OAuth-only accounts (Identity already supports this).
- `POST /api/auth/google` / `POST /api/auth/apple` — body `{ idToken }`, response identical to `POST /api/auth/login`'s `LoginResponse`. `ExternalSignInHandler` (`FreestyleCombo.API/Features/Auth/ExternalSignIn/`) verifies the token via `IIdTokenVerifier` (`JwksIdTokenVerifier`, `FreestyleCombo.AI/Services/` — verifies against each provider's public JWKS directly, no vendor SDK; rejects a token whose `email_verified` claim is present and `false`, but still trusts the email when that claim is absent entirely, since Apple doesn't reliably send it), then: matches by `(AuthProvider, ExternalSubject)` first (the only reliable key for returning users, since providers only send `email` on a user's first-ever grant); falls back to matching by `Email` and backfills `AuthProvider`/`ExternalSubject` onto that row if found (this is also how an existing password account gets auto-linked — no separate "link account" endpoint; if a user later signs in with a *different* second provider using the same email, this backfill overwrites the previous provider's values — accepted, documented behavior, not a bug); otherwise creates a new `AppUser` with `EmailConfirmed = true` and a username auto-generated from the email's local-part (uniqueness-suffixed: `rafael`, `rafael2`, ...). Invalid/expired/forged/unverified tokens, or a no-match-no-email dead end → `403` (same `UnauthorizedAccessException` → middleware mapping as a bad password on `/auth/login`).
- JWT issuance is shared with password login via `ITokenService`/`TokenService` (`FreestyleCombo.API/Features/Auth/`) — same 7-day single-token model as before, no refresh tokens.
- Config: `Auth:Google:Audiences` / `Auth:Apple:Audiences` (comma-separated OAuth client IDs / Apple audiences — see Environment variables table). Google web + iOS client IDs and Apple's audiences (`com.rafaelffs.freestyleCombo` + web Services ID `com.rafaelffs.freestyleCombo.web`) are both configured in `docker-compose.yml` — verified both endpoints load their config correctly (a placeholder token fails at JWT parsing, not the empty-audiences short-circuit). Production secrets not yet updated with these values. **Android is deliberately not set up yet** (no Google Cloud Android OAuth client, no `mobile/android/app/google-services.json`) — skipped for now, to be created later when Android release work starts.
- Mobile: `google_sign_in` + `sign_in_with_apple` packages, buttons in `SocialSignInButtons` (`mobile/lib/features/auth/social_sign_in_buttons.dart`), shared by `login_screen.dart` and `register_screen.dart`. Apple button is iOS-only (`Platform.isIOS`). `main.dart` calls `GoogleSignIn.instance.initialize(clientId: ...)` on startup with the iOS client ID, only on iOS (`Platform.isIOS ? _googleIosClientId : null`) — Android gets no clientId since it isn't configured yet, so Google sign-in will not work on Android until that setup lands. `ios/Runner/Info.plist` has the reversed iOS client ID registered as a `CFBundleURLTypes` scheme; `ios/Runner/Runner.entitlements` (Sign in with Apple capability) still needs to be added in Xcode — Apple sign-in won't work on iOS until that's done, even though the backend audience is already configured.
- Web: no new npm packages — Google Identity Services and Apple's JS SDK are loaded via injected `<script>` tags (module-scope promise-cached per script id, so concurrent mounts share one in-flight load rather than racing) in `SocialSignInButtons.tsx` (`web/src/features/auth/`), shared by `LoginPage.tsx`/`RegisterPage.tsx`. Buttons render only when `VITE_GOOGLE_CLIENT_ID`/`VITE_APPLE_CLIENT_ID` are set — `web/.env.example` documents both, `web/.env.local` (gitignored) holds both real values now, verified via the dev server that Vite actually injects them into the served page. Production web env vars not yet updated.
- Known limitation carried over from the design: `AppUser.Email` has no unique DB constraint (`RequireUniqueEmail` isn't set on Identity), so two near-simultaneous first-time OAuth sign-ups with the same email could theoretically both miss the lookup and create separate accounts instead of one linked account. Not fixed as part of this feature since it's a broader, pre-existing schema characteristic that would also change password registration's behavior — flagged here for future attention, not treated as a bug in `ExternalSignInHandler` itself.

### Error format
API middleware always returns `{ "error": "..." }`. Web uses `extractError(err, fallback)` helper from `lib/api.ts`. Mobile `_extractMessage` checks `data['error']` first, then `data['message']`, then `data['title']`.

### Preferences API (`/api/preferences`)
Users can have **multiple named preferences** (1:many). No limit on count. Future: public visibility (not yet implemented).

| Method | Route | Auth | Description |
|---|---|---|---|
| `GET` | `/api/preferences` | User | List all user's preferences |
| `POST` | `/api/preferences` | User | Create a named preference → returns `PreferenceDto` |
| `PUT` | `/api/preferences/{id}` | User | Update preference (owner check, 403 otherwise) → returns `PreferenceDto` |
| `DELETE` | `/api/preferences/{id}` | User | Delete preference (owner check, 403 otherwise) → 204 |

`PreferenceDto` includes `Id`, `Name`, and all settings fields. Request body: `PreferenceRequest` with `Name` (required, max 100) + all settings fields with defaults.  
Validation: `Name` NotEmpty MaxLength(100), same field limits as before. `AllowedRevolutions` items must be between `0.5` and `4.0`.

`MaxHighRevolutionTricks` (`int?`, 1–15, default `1`) caps how many tricks with **3+ revolutions** can appear in one generated/previewed combo — the hardest, rarest moves. No "unlimited" option — always a concrete value in the UI (the field stays nullable server-side only for pre-existing rows saved before this validation range existed). Same field on `UserPreference` and `GenerateComboOverrides` (resolved `Overrides ?? SavedPref ?? null`). Web: number input (min 1, max 15) in both the preference form and the generate-mode custom-overrides panel. Mobile: a plain slider (min 1, max 15, default 1) in both the preference form and generate-mode custom overrides — no separate enable/disable toggle.

`AllowedTrickIds` (`List<Guid>`, default empty) restricts combo generation/preview to only these tricks — an empty list means no restriction (full trick pool). Applied in Step 1 pool filtering, after the `AllowedRevolutions` filter: `Overrides?.AllowedTrickIds ?? SavedPref?.AllowedTrickIds ?? []`, only applied `.Where(t => allowedTrickIds.Contains(t.Id))` when non-empty. No validator rule (no existence check, same leniency as `AllowedRevolutions`). Web: `PreferencesPage` has a collapsible `TrickPicker` (search + checkbox list, lazy-loaded via `tricksApi.getAll()`, filtered to non-transition tricks) wired into the preference form only — not currently exposed in the web generate-mode quick-overrides panel. Mobile: `preferences_screen.dart`'s preference form has an "Allowed tricks (N selected)" row that opens a bottom-sheet picker (search + `CheckboxListTile` list, lazy-loaded via `ApiClient.instance.getTricks()`, filtered to non-transition tricks). Mobile's `create_combo_screen.dart` generate view ("Custom" base preset) has the same picker row wired to `GenerateComboOverrides.allowedTrickIds` — when a saved preset is selected instead, the row becomes a read-only banner showing the preset's own allowed-trick count instead of an editable control.

### Trick Submission API (`/api/trick-submissions`)
| Method | Route | Auth | Description |
|---|---|---|---|
| `POST` | `/` | Any user | Submit a new trick for review |
| `GET` | `/mine` | Any user | Get current user's own submissions |
| `GET` | `/pending` | Admin | Get all pending submissions |
| `POST` | `/{id}/approve` | Admin | Approve → creates a `Trick` |
| `POST` | `/{id}/reject` | Admin | Reject the submission |

Validation for `SubmitTrickCommand`: Name NotEmpty MaxLength(100), Abbreviation NotEmpty MaxLength(20), Revolution InclusiveBetween(0.5, 4), Difficulty InclusiveBetween(1, 10), CommonLevel InclusiveBetween(1, 10).

### JWT — Role claim
`LoginHandler.GenerateToken()` now calls `GetRolesAsync(user)` and adds `ClaimTypes.Role` claims. The `Admin` role is included in the JWT for admin users. Web/mobile decode the JWT payload client-side to check `isAdmin` — no extra API call needed.

### Anthropic SDK (v5.10.0) — Correct usage
```csharp
using Anthropic.SDK;
using Anthropic.SDK.Constants;
using Anthropic.SDK.Messaging;

// Model: AnthropicModels.Claude45Haiku
// Message type: TextContent (NOT TextBlock)
// Role: RoleType.User
```

### Swagger / OpenAPI 2.0 — Correct usage
```csharp
using Microsoft.OpenApi;  // NOT Microsoft.OpenApi.Models

// Security scheme reference:
new OpenApiSecuritySchemeReference("Bearer")

// Security requirement:
AddSecurityRequirement(_ => new OpenApiSecurityRequirement {
    { new OpenApiSecuritySchemeReference("Bearer"), new List<string>() }
})
```

### Validation limits (enforced in FluentValidation + UI)
| Field | Min | Max | Applied in |
|---|---|---|---|
| `ComboLength` | 1 | **100** | `GenerateComboValidator`, `UpdatePreferencesValidator`, all UIs |
| `MaxConsecutiveNoTouch` | 0 | **30** | `GenerateComboValidator`, `UpdatePreferencesValidator`, all UIs |
| `MaxDifficulty` | 1 | 10 | all validators + UIs |
| `StrongFootPercentage` | 0 | 100 | all validators + UIs |
| `NoTouchPercentage` | 0 | 100 | all validators + UIs |
| `Revolution` | 0.5 | **4** | Trick create/update/submission validators — **must also be a multiple of 0.5** (`r * 2 % 1 == 0`), same three validators. Mobile's admin trick-edit `_NumField` snaps to the nearest 0.5 on input (matching the submit form's slider); web's create/edit/submit inputs already had `step={0.5}`. |
| `AllowedRevolutions[]` | 0.5 | **4** | Preference + combo override validators |
| `MaxHighRevolutionTricks` | **1** | **15** | `GenerateComboValidator`, `PreviewComboValidator`, `CreatePreferenceValidator`, `UpdatePreferencesValidator` — nullable, only validated `.When(HasValue)`; UI always sends a value (default 1) |

### Combo generation algorithm
**Preview** (steps 1–5, `POST /api/combos/preview`): no AI, no DB save — returns trick list + warnings.  
**Generate** (all 6 steps, `POST /api/combos/generate`): saves to DB, calls AI for description.

1. Filter trick pool (MaxDifficulty, IncludeCrossOver, IncludeKnee, AllowedRevolutions)
2. Split slot *count* by StrongFoot % (which foot performs a trick is independent of the trick's own CrossOver property — both slot kinds draw from the same pool; see `git log` on `GenerateComboHandler.cs` if this looks like it should be a pool split, it deliberately isn't)
3. Weighted random pick (weight = `CommonLevel`); fill by position
3.5. If `MaxHighRevolutionTricks` is set, cap tricks with `Revolution >= 3`: randomly re-roll excess ones from the sub-pool of tricks with `Revolution < 3` (adds a warning instead if that sub-pool is empty)
4. Shuffle positions
5. Annotate NoTouch — only CrossOver tricks, respecting NoTouchPercentage & MaxConsecutiveNoTouch
6. (Generate only) Call `IComboEnhancerService.EnhanceAsync()` → Claude AI description → save combo

### Moq requirements
- `ComboRatingAggregator.AdjustWeightsAsync` is `public virtual` (required for Moq)
- `IComboEnhancerService` is an interface (extracted from `ComboEnhancerService`)

### Migrations
```bash
cd api
dotnet ef migrations add <Name> --project FreestyleCombo.Infrastructure --startup-project FreestyleCombo.API
dotnet ef database update --project FreestyleCombo.Infrastructure --startup-project FreestyleCombo.API
```

---

## Web — Key Details

### Tech stack
- **React 19 + Vite + TypeScript** · **Tailwind CSS v4** (`@tailwindcss/vite`) · **TanStack Query v5** · **React Router v7** · **axios** · **shadcn-style components** (Radix UI + CVA + clsx + tailwind-merge) · **i18next + react-i18next + i18next-browser-languagedetector**

### Internationalization (i18n)
- Library: `react-i18next` with `i18next-browser-languagedetector`
- Supported languages: `en` (English), `pt-BR` (Portuguese Brazil) — `pt` also maps to pt-BR
- Auto-detection order: `localStorage` → browser `navigator` locale
- Manual override: language toggle button in Navbar (desktop + mobile drawer)
- Navbar language indicator normalizes detected locales by language family: default UI uses emoji flags (`🇺🇸`/`🇧🇷`); on Windows clients it falls back to inline flag icon + label (`EN`/`PT-BR`) for reliable rendering
- Persistence: `localStorage` key `fc_lang` stores the user's manual choice
- Translation files: `web/src/locales/en.json`, `web/src/locales/pt-BR.json`
- Config: `web/src/lib/i18n.ts` (imported as side-effect in `main.tsx`)
- All user-facing strings use `useTranslation()` hook — do not add hardcoded English strings to components

### Directory structure
```
web/src/
├── lib/
│   ├── api.ts          # axios instance, all API functions + DTO types + extractError()
│   ├── auth.ts         # localStorage token management + isAdmin() (JWT decode)
│   └── utils.ts        # cn() helper (clsx + tailwind-merge)
├── components/
│   ├── ui/             # Button, Input, Label, Card, Badge, Textarea, Select, Dialog
│   └── layout/         # Navbar, Layout (Outlet), ProtectedRoute, AdminRoute
└── features/
    ├── auth/           # LoginPage (email or username), RegisterPage
    ├── combos/         # CombosPage (tabbed: Public + Mine), CreateComboPage (mode: choose/generate/build),
    │                   # ComboDetailPage (with inline edit for owners), ComboCard, RateComboDialog,
    ├── preferences/    # PreferencesPage
    ├── tricks/         # TricksPage (/tricks, public, inline submit form), AdminSubmissionsPage (/admin/approvals)
    └── legal/          # PrivacyPage (/privacy), TermsPage (/terms) — static, i18n'd, required for App Store/Play Store review
```

Routes: `/combos` (public, tabbed), `/combos/create` (protected, mode selector), `/admin/approvals` (admin only), `/admin/users` (admin only), `/account` (protected), `/users/:id` (public). Old admin routes `/admin/submissions` and `/admin/combo-reviews` redirect to `/admin/approvals`. Create route remains accessible from the "Create new" button inside `/combos`.

`CreateComboPage` modes: `'choose'` (initial), `'generate'` (calls `/preview` → populates build slots on success), `'build'` (manual slot picker + save). Name field is at the top, shared across all modes. In generate mode: a `<select>` dropdown lists user's saved preferences by name (first option: "Custom"). When a preference is selected, all fields are shown read-only/locked; when "Custom", all fields are editable. Passes `preferenceId` (not the old `usePreferences` bool) to preview API.

`PreferencesPage` shows a list of named preference cards with Edit/Delete per card and a "New preference" button at the top. Create/edit opens an inline form in a new Card. Delete shows a confirm button inline before removing.

`AdminRoute` redirects non-admins to `/combos`. `isAdmin()` decodes the JWT payload (no library, no API call) and checks `ClaimTypes.Role === "Admin"`.

`PrivacyPage` (`/privacy`) and `TermsPage` (`/terms`) are static, i18n'd (`legal.privacy.*` / `legal.terms.*` keys, sections numbered `section{N}Title`/`section{N}Body`), linked from a footer added to `Layout.tsx`. Required by both Apple App Review and Google Play before submission — reachable at `https://www.fscombo.com/privacy` and `/terms`.

### Web Navigation (post-merge)
| Link | Route | Visible |
|---|---|---|
| Combos | `/combos` | Always |
| Tricks | `/tricks` | Always |
| Preferences | `/preferences` | Authenticated |
| Approvals | `/admin/approvals` | Admin only |
| Users | `/admin/users` | Admin only |

Navbar right side shows a profile dropdown (username + chevron) when authenticated: "My Account" → `/account`, then "Logout". Unauthenticated shows Login/Register buttons.

`auth.ts` stores username in localStorage (`fc_user_name`) extracted from the JWT `unique_name` claim. `getUserName()` and `setUserName()` are exported.

### Account & User Profile
- `GET /api/account/me` — returns `ProfileDto { id, userName, email, isAdmin }` (auth required)
- `PUT /api/account/me` — update username/email
- `PUT /api/account/me/password` — change password (requires currentPassword)
- `DELETE /api/account/me` — self-service account deletion (auth required, no admin needed) — deletes the calling user via `UserManager.DeleteAsync`, same EF-cascade behavior as the admin delete endpoint. Required by Apple App Review Guideline 5.1.1(v) (any app with account creation must offer in-app account deletion).
- `GET /api/account/{id}` — public profile `PublicProfileDto { id, userName, email }` (no auth)
- `AccountPage` at `/account` — three sections: edit profile form, change password form, and a "Delete Account" danger-zone section (confirm via `window.confirm`, then clears the token and redirects to `/login`)
- `UserProfilePage` at `/users/:id` — shows username + email with initial avatar
- "by [username]" on ComboCard links to `/users/{ownerId}`

### Admin User Management (`/api/admin/users`)
- `GET /api/admin/users` — list all users with `AdminUserDto { id, userName, email, isAdmin, comboCount }`
- `PUT /api/admin/users/{id}` — edit username/email
- `PUT /api/admin/users/{id}/password` — reset password (no current password required)
- `PUT /api/admin/users/{id}/role` — `{ isAdmin: bool }` — assign/revoke Admin role
- `DELETE /api/admin/users/{id}` — delete user account (EF cascades handle related data)
- `AdminUsersPage` at `/admin/users` — table with Edit/Reset pw/Toggle admin/Delete per row

### ComboCard features
- Shows `combo.name` (bold, above displayText) when present
- Shows `combo.ownerUserName` (not ownerEmail)
- "by [username]" is a link to `/users/{combo.ownerId}` when ownerId is set
- Favourite toggle: heart icon only (no text label), displayed in a top icon row above combo name — calls `addFavourite`/`removeFavourite`, invalidates `['combos']` query
- Visibility is icon-based near actions (owner only): globe icon only (`🌐`) with neutral color for private (click opens confirm modal to submit as public), yellow for pending approval, blue for public
- No Private/Public text badges on combo cards
- Delete button removed from cards; deletion is available on `ComboDetailPage` only (owner or admin)
- Weak-foot tricks shown as `(wf)` (not `wk`)

### Difficulty badge
- No "d" prefix — just the number
- Color-coded: `bg-green-100 text-green-800` (1–4), `bg-yellow-100 text-yellow-800` (5–7), `bg-red-100 text-red-800` (8–10)
- Applied in `CreateComboPage` build mode (trick picker) and `TricksPage` (Diff column)
- `TricksPage` no longer shows a "Level" (commonLevel) column in the table

### Path alias
`@/` → `web/src/` (configured in `vite.config.ts` + `tsconfig.app.json`)

### API proxy
Dev server proxies `/api/*` → `http://localhost:5050` (Vite `server.proxy`)

---

## Docker

```bash
# Start everything
docker-compose up

# API container: internal port 8080, host port 5050
# Swagger: http://localhost:5050/swagger
# Hangfire: http://localhost:5050/hangfire
```

`appsettings.Development.json` is gitignored — set `Anthropic__ApiKey` via env var or in `docker-compose.yml`.

---

## Production Deployment

**Live at `https://www.fscombo.com`** — API + web are in production (see `DeploymentPlan/DEPLOYMENT.md` for the original rollout plan). Mobile is not yet submitted to app stores.

- **Infra**: single Hetzner VPS running Docker Compose (`docker-compose.prod.yml`: API + Postgres, both bound to `127.0.0.1` only) behind a host Nginx (`nginx/nginx.conf`) doing TLS termination (Let's Encrypt) and reverse-proxying `/api/` to the API container; React `web/dist/` is served as static files from `/var/www/freestylecombo`.
- **CD**: `.github/workflows/deploy.yml` runs after CI succeeds on `main` — builds the API into a Docker image pushed to GHCR, builds the React app, rsyncs both + nginx config to the VPS over SSH, swaps only the API container (DB untouched), reloads Nginx, then verifies `/api/tricks` responds. Secrets: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`.
- **Mobile release readiness**: `mobile/lib/core/api/api_client.dart`'s `kBaseUrl` points release builds at `https://www.fscombo.com/api` (debug builds still default to localhost — see "API base URL" below). No cleartext/ATS exceptions needed since prod is HTTPS-only.
- **App Store prerequisites now in place**: production backend reachable over HTTPS, `/privacy` and `/terms` pages live, self-service account deletion (`DELETE /api/account/me`, wired into both `AccountPage` (web) and `account_screen.dart` (mobile)) per Apple Guideline 5.1.1(v), 1024px app icon already in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`. Apple Developer Program membership is active and paid — Team ID `6K8AXR83Y3` is set (`DEVELOPMENT_TEAM` in `ios/Runner.xcodeproj`, `CODE_SIGN_STYLE = Manual`, written by fastlane's `update_code_signing_settings`). Bundle ID `com.rafaelffs.freestyleCombo` is registered and the App Store Connect app record exists (app id `6806225332`). A demo/review account is seeded on production (`applereview` / see 1Password or ask the account owner — verified live via `/api/auth/login`). TestFlight has an "Internal Testers" group; builds 1–5 are all `VALID` and export-compliance-cleared. Build 6 (`1.0.0+6`) is the first to include Google/Apple sign-in, uploaded via `fastlane ios beta` — needs `fastlane ios clear_export_compliance` before it's usable in TestFlight, same as every prior build. App Store screenshots (6.9" class, 1320×2868, branded) are in `design/appstore-screenshots/marketing/`.

**Release build pipeline fixes (as of build 6):** `mobile/fastlane/Fastfile`'s `build`/`beta` lanes had three latent bugs, all fixed — see commit `7bda851` for the full story. (1) `flutter build ipa`'s CocoaPods check resolves `ruby` via PATH, which pointed at system Ruby instead of the Homebrew Ruby CocoaPods was actually installed against, falsely reporting "CocoaPods not installed" — fixed by prepending Homebrew's Ruby to `ENV["PATH"]` at the top of the Fastfile. (2) The Xcode project's `CODE_SIGN_ENTITLEMENTS` build setting was never pointing at `Runner/Runner.entitlements`, so entitlements (e.g. Sign In with Apple) were never actually embedded regardless of which provisioning profile matched — fixed via a fresh `pod install` + `update_code_signing_settings` run, now committed. (3) `flutter build ipa`'s own default export step doesn't reliably honor manual signing — fixed by adding `mobile/ios/ExportOptions.plist` (explicit `signingStyle: manual`, profile named directly) passed via `--export-options-plist`. Also: `sigh`'s `output_path` (`~/.appstoreconnect/freestylecombo-signing/`) is **not** the same as the system provisioning-profile store (`~/Library/MobileDevice/Provisioning Profiles/`) that `xcodebuild` actually reads — after any `setup_signing` run, the regenerated profile needs manually copying into the latter (named `<UUID>.mobileprovision`, with any old same-named profile removed first) before `fastlane ios build` will pick it up. This copy step is not yet automated in the Fastfile.
- **Still needed before App Store submission** (steps only the account owner can do, in App Store Connect's web UI — not automatable via fastlane/API without the owner's business sign-off): create an App Store version, attach a TestFlight build, upload the screenshots, fill in listing copy (name/subtitle/description/keywords), complete the age-rating and App Privacy questionnaires, then submit for review. Note: the app has public user-generated content (combo names, usernames) gated by admin approval before going public, but no in-app block/report mechanism — worth a mention in App Review notes or an explicit call on whether Guideline 1.2 requires adding one before submitting.

---

## Mobile — Flutter (Phase 3)

### Tech stack
- **Flutter 3.19+** · **Dart 3.3+** · **go_router** (navigation) · **dio** (HTTP) · **shared_preferences** (token storage) · **google_fonts** (Plus Jakarta Sans + JetBrains Mono, see "Visual design" below)
- No external state management library — plain `StatefulWidget` + `FutureBuilder`

### Visual design (redesign, post-merge)
The mobile client follows `design/mobile-redesign/design_spec.md` (visual reference: `design/mobile-redesign/mocks.html`) — indigo/violet gradient system with a lime energy accent, Plus Jakarta Sans UI type, JetBrains Mono for combo/trick notation, radius-24 cards. Both fonts are loaded via `google_fonts` (no bundled font assets). This was a **visual-only** redesign — `core/api/api_client.dart`, all `core/models/`, `core/auth/auth_service.dart`, and `router/app_router.dart` were not touched.

- `lib/theme/app_colors.dart` — `AppColors` class holding every design token (indigo/violet/lime, ink/muted/faint text scale, bg/surface/line, green/amber/red difficulty scale + backgrounds, pink/star/no-touch accents, chip/indigo-tint neutrals, and the `grad` gradient). `main.dart` wires `ThemeData` with `GoogleFonts.plusJakartaSansTextTheme()`, `scaffoldBackgroundColor: AppColors.bg`, and a matching `AppBarTheme`.
- `lib/widgets/difficulty_chip.dart` — shared `DifficultyChip(int)` widget (green ≤4, amber 5–7, red 8–10, JetBrains Mono numeral). Used on combo cards' trick chips, `combo_detail_screen.dart`'s sequence, `create_combo_screen.dart`'s trick picker, and `tricks_screen.dart` rows.
- `lib/features/auth/auth_chrome.dart` — shared `AuthScaffold`/`AuthField`/`AuthPrimaryButton` gradient-hero + white-sheet chrome used by both `login_screen.dart` and `register_screen.dart`.
- `lib/features/auth/social_sign_in_buttons.dart` — shared `SocialSignInButtons` (Google/Apple) used by both `login_screen.dart` and `register_screen.dart` — see "Google & Apple Sign-In" above.

### Directory structure
```
mobile/lib/
├── main.dart
├── theme/app_colors.dart         # Design tokens (AppColors) — see "Visual design" above
├── core/
│   ├── api/api_client.dart       # Dio client, all API methods, singleton
│   │                             # _extractMessage checks data['error'] first
│   ├── auth/auth_service.dart    # Token + isAdmin in SharedPreferences, JWT decode
│   └── models/
│       ├── combo.dart            # TrickDto, BuildComboTrickItem, ComboDto, ComboTrickDto,
│       │                         # PagedResult, GenerateComboOverrides, PreviewTrickItem,
│       │                         # PreviewComboResponse
│       ├── user_preference.dart  # UserPreference with toJson/copyWith (allowedRevolutions)
│       └── trick_submission.dart # TrickSubmissionDto with fromJson
├── features/
│   ├── auth/                     # login_screen.dart / register_screen.dart (gradient hero + sheet,
│   │                             # via auth_chrome.dart), credential field unchanged
│   ├── combos/                   # combos_screen.dart (segmented Public/Mine/Favourites),
│   │                             # create_combo_screen.dart (mode: choose/generate/build),
│   │                             # combo_detail_screen.dart (gradient hero, numbered sequence,
│   │                             # inline edit for owners)
│   ├── preferences/              # preferences_screen.dart ("Presets" — preset cards only,
│   │                             # no account/logout — see account_screen.dart)
│   ├── tricks/                   # tricks_screen.dart (/tricks, public, appbar "+" → submit bottom sheet)
│   ├── account/                  # account_screen.dart — full Profile screen (gradient header,
│   │                             # stats, account links); edit-profile/password moved to a
│   │                             # pushed `_EditProfileScreen` (Navigator.push, no new route)
│   └── admin/                    # admin_submissions_screen.dart (/admin/approvals)
├── router/app_router.dart        # GoRouter config, auth + admin redirect; initialLocation: /combos
└── widgets/
    ├── main_shell.dart           # Bottom nav: Combos, Tricks, center gradient Generate FAB,
    │                             # Presets + Profile (authed) or Login (unauthed), + Admin (admin)
    ├── combo_card.dart           # name display, ownerUserName, fav/done/rate icon row, footer stats + visibility tag
    ├── difficulty_chip.dart      # shared DifficultyChip(int) — see "Visual design" above
    └── rate_combo_dialog.dart    # Star rating AlertDialog
```

`AuthService.isAdmin` decodes the JWT on `setCredentials()` and persists the result in SharedPreferences (`fc_is_admin`). `AuthService.userName` extracts `unique_name` claim from JWT and persists in SharedPreferences (`fc_user_name`). Admin routes (`/admin/*`) are redirect-guarded in the router.

`preferences_screen.dart` ("Presets" tab) is now preset cards only (icon, name, Edit, Delete, 3 mono stat tiles: Length/Max diff/No-touch, plus a muted flags caption) — the account card and logout button moved to `account_screen.dart`. FAB moved into an appbar "+" icon button; opens `_PreferenceForm` in a `showModalBottomSheet`.

`account_screen.dart` at `/account` is now the "Profile" screen: gradient header (avatar initial, username, Combos/Done/Avg★ stats aggregated client-side from `getMyCombos()` — no new API calls), then "Edit profile & password" / "My combos" / "Log out" / "Delete account" row-links. Edit profile + change password now live in a pushed `_EditProfileScreen` (`Navigator.push`, not a router route). Logout navigates to `/combos` (previously navigated to the non-existent `/public` route from `preferences_screen.dart` — fixed as part of relocating the control). "Delete account" is a destructive-styled `_RowLink` (red icon/text, `AppColors.redBg` chip) that confirms via `AlertDialog`, calls `ApiClient.instance.deleteAccount()` (`DELETE /api/account/me`), then clears auth and goes to `/combos` — required by Apple App Review Guideline 5.1.1(v).

`user_profile_screen.dart` at `/users/:id` — restyled with the same gradient hero pattern as `account_screen.dart` (back button, avatar initial, username, email), scaled down since public profiles carry no stats/actions.

`admin_users_screen.dart` at `/admin/users` — ListView of restyled user row cards (avatar tile, ADMIN badge, PopupMenuButton unchanged: Edit/Reset password/Toggle admin/Delete). Edit and reset-password dialogs use the shared `_FormDialog`/`_DialogField` look (rounded 20, indigo confirm button); delete confirmation uses a red `FilledButton`.

`admin_submissions_screen.dart` at `/admin/approvals` — restyled with `_SectionHeader`s ("Combo publication requests" / "Trick submissions"), card-shell items (`_ComboReviewCard`, `_TrickSubmissionCard`) reusing `DifficultyChip` and mono trick chips, and a shared Approve (indigo)/Reject (red outline) row.

`create_combo_screen.dart` generate view: preference selector is now a horizontal row of preset chips (first chip "Custom" = null) instead of a dropdown; selecting a preset still copies its values into state and locks the custom sliders/switches (`onChanged: null`). Sliders are a custom-painted `_AppSlider` (gradient fill track + ringed knob, JetBrains Mono value label) rather than Material `Slider`. A sticky bottom action bar holds the "Generate combo" button (calls `_preview()`, same preview→build-tab flow as before). Toggles use `CupertinoSwitch`. Build-tab slot rows and the picker list are restyled but functionally unchanged. The nested `_EditComboScreen` (combo detail's inline edit) and `_InlineSubmitForm`/`_EditTrickDialog` (tricks screen) got the same slider/toggle/field treatment.

`create_combo_screen.dart` generate view: selecting "Custom" after a preset was selected resets every copied-over field (combo length, difficulty, foot/no-touch %, max consecutive no-touch, max 3+ rev tricks, cross-over/knee toggles, allowed-tricks filter) back to defaults, not just the selected-preset pointer — previously only the pointer reset, so e.g. the allowed-tricks filter stayed applied after switching back to Custom. Web's generate flow never had this bug (it reads preset values for display without writing them into its own override state).

Both the manual build-save panel (`create_combo_screen.dart`'s `_buildComboTab()`, `CreateComboPage.tsx`) and the post-save `_EditComboScreen` (mobile) / edit mode (`ComboDetailPage.tsx`, web) expose two independent toggles: "Submit as public" (mobile edit screen only — the build/generate flow already had it; shown only while the combo is `Private`, calls `setVisibility`/`combosApi.setPublic` after the base update succeeds) and "Reusable for me" (all four surfaces; shown regardless of visibility, calls `setPersonalReusable`/`combosApi.setPersonalReusable`). Both call a second endpoint after the base build/update call succeeds, mirroring the two-call pattern already used for admin approval flows.

`admin_combo_reviews_screen.dart` is dead code — unreferenced since `/admin/combo-reviews` redirects to `/admin/approvals` and `admin_submissions_screen.dart` already covers combo review approvals itself. Left as-is (not restyled, not deleted) since removing it wasn't requested.

### Mobile Navigation (post-merge)
| Slot | Label | Route | Visible |
|---|---|---|---|
| 1 | Combos | `/combos` | Always |
| 2 | Tricks | `/tricks` | Always |
| center | (gradient lightning FAB) | `/combos/create` | Always |
| 3 | Presets | `/preferences` | Authenticated |
| 4 | Profile | `/account` | Authenticated |
| 3 (unauth) | Login | `/login` | Unauthenticated |
| 5 | Admin (badge = pending approvals count) | `/admin/approvals` | Admin only |

New mobile routes: none added — `/account`, `/users/:id`, `/admin/users` already existed. `combos_screen.dart`'s own FloatingActionButton was removed since the bottom-nav FAB now covers combo creation (the "Create your first combo" empty-state CTA on the Mine tab still exists).

`widgets/submit_trick_sheet.dart` — shared `showSubmitTrickSheet()` + `SubmitTrickForm` (extracted from `tricks_screen.dart`'s formerly-private `_InlineSubmitForm`; `SubmitToggle` within it is public and also reused by `_EditTrickDialog` and the combo edit screens' "Submit as public"/"Reusable for me" toggles). `tricks_screen.dart`'s search and the manual combo-build trick picker (`create_combo_screen.dart`'s `_buildPickerTab()`) both show a "Missing a trick? Submit '\<query\>'" empty state when a search matches nothing, prefilling the submit sheet's name field with the search text. `tricks_screen.dart`'s sort-by bottom sheet (tune icon) also has a "Filter by revolutions" section below "Sort by", reusing the same `_selectedRevs` state as the standalone "Revs" chip (both remain — additive, not a replacement).

`combos_screen.dart` has a "Done" filter chip (authed only, next to the Full name/Abbr. toggle) that client-side filters whichever tab (Public/Mine/Favourites) is active down to `combo.isCompleted`. `ComboCard`'s completion toggle now calls `widget.onRefresh?.call()` after marking/unmarking done (previously only the favourite toggle did this) so the parent list's cached `isCompleted` — and this filter — stays in sync immediately.

### combo_card.dart features
- Shows `combo.name` (bold, 17/800) above `displayText` (JetBrains Mono) when present, with a gradient `DIFF` badge (top-right) showing `totalDifficulty`
- Shows `combo.ownerUserName` (not ownerEmail) as an indigo "by [username]" link → `/users/{ownerId}` when set
- Top icon row (authed only): favourite toggle, done toggle (+ count), rate button (non-owners only, opens `RateComboDialog`) — small bordered square icon buttons
- Trick chips: `1. ATW` (JetBrains Mono, position in faint), no-touch chips tinted violet; sub-combo chips fall back to `subComboName` if `abbreviation` is null; "+N" overflow chip expands the list inline (existing cap-at-6 logic preserved)
- Footer row (top hairline border): ★ average rating (if any ratings), ✓ done count, spacer, visibility tag (Public=blue/Pending=amber/Private=grey) — tappable only when `canActOnVisibility`, same confirm-sheet flow as before
- Weak-foot tricks shown as `·wf`, no-touch as `·nt` — suppressed for transition tricks (e.g. "Combo"), which have no foot/no-touch of their own; same suppression applies in `combo_detail_screen.dart`'s hero/sequence and the web equivalents (`ComboCard.tsx`, `ComboDetailPage.tsx`, `CreateComboPage.tsx`, `TricksPage.tsx`'s reusable-combo expansion, `AdminSubmissionsPage.tsx`). The root cause was the inline "edit combo" screens (mobile `_EditComboScreen`, web `ComboDetailPage.tsx` edit mode) not knowing about `isTransition` at all, unlike the main build flow — both now hide the SF/NT controls for transition slots and normalize away stale flags on load.
- The `TrickNameDisplay.showFullName` toggle (full name vs. abbreviation, global static flag) was previously only settable from `combos_screen.dart`'s header, and `combo_detail_screen.dart`'s SEQUENCE list ignored it entirely — trick rows there always hardcoded `t.name`. `combo_detail_screen.dart` now has its own Full name/Abbr. chip pair next to the "SEQUENCE" header (same flag, same styling as `combos_screen.dart`'s), and its per-trick label reads `TrickNameDisplay.label(...)` like every other trick-name surface. The nested sub-combo trick-chip list inside an expanded sub-combo step is unaffected — like `combo_card.dart`'s own trick chips, it always shows abbreviations.

### Difficulty chip (mobile)
- Shared `DifficultyChip(int)` in `widgets/difficulty_chip.dart` — green/greenBg (1–4), amber/amberBg (5–7), red/redBg (8–10), JetBrains Mono numeral
- Used in `tricks_screen.dart` rows, `combo_detail_screen.dart` sequence, `create_combo_screen.dart` trick picker, and combo cards' gradient DIFF badge (a separate, larger `_DiffBadge` widget local to `combo_card.dart`)
- `tricks_screen.dart` subtitle still doesn't show common level (`lvl X`)

### Setup (Flutter must be installed first)
```bash
cd mobile

# If no platform folders exist yet, scaffold them:
flutter create . --org com.rafaelffs --project-name freestyle_combo --platforms android,ios,web

flutter pub get
flutter run
```

### API base URL (`lib/core/api/api_client.dart`)
`kBaseUrl` switches on `kReleaseMode`: release builds (TestFlight/App Store, Play Store) always point at production — `https://www.fscombo.com/api`. Debug builds default to localhost; edit the debug branch when testing against something else:
- Android emulator: `http://10.0.2.2:5050/api`
- iOS simulator: `http://localhost:5050/api`
- Web (Chrome): `http://localhost:5050/api`
- Physical device: your machine's local IP, e.g. `http://192.168.1.x:5050/api`

### Key design decisions
- `AuthService` and `ApiClient` are manual singletons (no DI framework) for simplicity
- `register` returns `201` with no token → app calls `login` immediately after to get the JWT
- `FutureBuilder` pattern used throughout — no Riverpod/BLoC overhead
- `withValues(alpha:)` used instead of deprecated `withOpacity` in Flutter 3.19+

---

## Running locally (without Docker)

```bash
# API (requires local postgres on 5432)
cd api/FreestyleCombo.API
dotnet run

# Web
cd web
npm run dev       # → http://localhost:5173

# Mobile
cd mobile
flutter run
```

---

## Tests

```bash
cd api
dotnet test
```

230 unit tests covering: combo generation/build/preview, combo visibility and deletion permissions, combo query/update handlers, pending combo review mapping, favourites/completions, auth login/register flows, account/admin handler flows, trick CRUD handlers, preference CRUD handlers, trick submission review flows, query handlers (tricks/preferences/ratings/pending approvals/submissions), revolution boundary validation (trick create/update/submission — including the half-increment constraint, preference and combo override allowed revolutions, preview override validation, rating score bounds), weight adjustment job/aggregator behavior, reusable combo repository methods, GetTricks unified response, SetReusable endpoint, BuildCombo/UpdateCombo sub-combo slot support, DeleteCombo sub-combo guard, reusable combo visibility guard (cannot be set non-public), personal reusable combos (AddPersonalReusable/RemovePersonalReusable authorization — owner at any visibility, non-owner only on Public, admin bypass on non-Public combos, GetReusableAsync per-user merge including a combo someone else added, BuildCombo/UpdateCombo sub-combo acceptance for whoever added it vs. rejection for anyone who hasn't), and Google/Apple external sign-in (`ExternalSignInHandler` — subject-first match, email fallback with provider/subject backfill onto an existing password account including overwrite-on-second-provider, auto-generated/collision-checked username on new-account creation, invalid-token and no-match-no-email rejection).

---

## Environment variables

| Variable | Where | Description |
|---|---|---|
| `ConnectionStrings__DefaultConnection` | docker-compose / appsettings | PostgreSQL connection |
| `JwtSettings__Secret` | docker-compose / appsettings | Min 32 chars |
| `JwtSettings__Issuer` | docker-compose / appsettings | `FreestyleComboAPI` |
| `JwtSettings__Audience` | docker-compose / appsettings | `FreestyleComboApp` |
| `Auth__Google__Audiences` | docker-compose / appsettings | Comma-separated Google OAuth client IDs (web, iOS, Android) — currently empty, sign-in fails closed until set |
| `Auth__Apple__Audiences` | docker-compose / appsettings | Comma-separated Apple audiences (iOS bundle ID, web Services ID) — currently empty, sign-in fails closed until set |
| `Anthropic__ApiKey` | docker-compose / appsettings | Claude API key |
| `Resend__ApiKey` | docker-compose / appsettings | Resend API key for forgot-password emails — omit to no-op (logs a warning) instead of sending |
| `Resend__FromAddress` | docker-compose / appsettings | Optional — defaults to `FreestyleCombo <onboarding@resend.dev>` |

---

## GitHub

Repo: `https://github.com/rafaelffs/FreestyleCombo`  
CI: `.github/workflows/ci.yml` — triggers on push to `main` and `feature/**`
