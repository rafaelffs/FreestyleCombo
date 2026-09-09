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
| `GET` | `/api/combos/{id}` | Public (optionally authed) | Get one combo — **viewable by anyone holding its id, regardless of `Visibility`** (see "Combo link sharing" below); `IsFavourited`/`IsCompleted`/`IsPersonalReusable` are still per-requesting-user. |
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

#### Combo link sharing

`GET /api/combos/{id}` (`GetComboHandler`) deliberately has **no ownership/visibility gate** — anyone holding a combo's id can view it via this endpoint regardless of `Visibility` (Private/PendingReview/Public). Same "anyone with the link can view" trust model as Google Docs/Figma share links: GUIDs aren't enumerable, and the listing endpoints (`GetPublicCombos`/`GetMyCombos`) still filter by `Visibility`, so a non-public combo stays undiscoverable by browsing — only reachable if its id was deliberately shared. The mapping logic is factored into `ComboDetailMapper.Map(...)` (`FreestyleCombo.API/Features/Combos/GetCombo/ComboDetailMapper.cs`), shared by `GetComboHandler`.

`ShareController` (`FreestyleCombo.API/Controllers/ShareController.cs`, route `share/combos/{id}`, **not** under `/api/`) serves a server-rendered HTML page with Open Graph / Twitter Card meta tags (title/description/image, built from the combo's name-or-abbreviation-sequence, trick count, difficulty, owner) plus a `<meta http-equiv="refresh">` + JS redirect to the real SPA URL (`/combos/{id}`) — this is what makes shared links render as rich preview cards in iMessage/WhatsApp/Slack instead of a bare URL. Also has no visibility gate (matches `GetComboHandler`). **Must be reverse-proxied**: this route lives outside `/api/`, so both `nginx/nginx.conf` (production) and `web/vite.config.ts` (local dev) need an explicit `/share/` proxy block to `127.0.0.1:5050` — the production nginx config was missing this for a while (dev's Vite proxy had it, production's nginx didn't), which silently broke every shared link in production; fixed by adding a matching `location /share/` block to `nginx/nginx.conf`.

Share UI: web `ComboCard.tsx`/`ComboDetailPage.tsx` and mobile `combo_card.dart`/`combo_detail_screen.dart` (via the `share_plus` package) show a share affordance for the combo's owner (any visibility) or anyone when the combo is `Public`. `navigator.share`/`Share.share` (native share sheet, when available) shares the `share/combos/{id}` URL (for the rich-preview redirect); the desktop clipboard-copy fallback copies the plain `/combos/{id}` SPA URL directly.

#### Share to Instagram (mobile only)

A second option alongside "Share Link" on the combo detail screen's share button (`combo_detail_screen.dart`'s `_openShareOptions` now opens `share_options_sheet.dart`'s choice sheet instead of calling `Share.share` directly). Generates a **full Story-canvas-sized transparent PNG** (not a small floating card) — the combo name/stats sit in a bottom text band over a black-to-transparent scrim; everywhere else stays transparent so the person's own photo/video shows through. Handed to Instagram via the native `instagram-stories://` sticker-share mechanism (`UIPasteboard` + a platform channel, `ios/Runner/InstagramShareBridge.swift`, mirroring the existing `WatchBridge.swift` pattern) — Instagram still lets the person nudge/resize it like any sticker, but since it matches the canvas exactly it starts already filling the screen.

Three layouts (`InstagramOverlayStyle`: Minimal/Sequence/Stat) share five independent display toggles (`InstagramOverlayToggles`: name/difficulty/quantity/rating/sequence — `mobile/lib/core/models/instagram_overlay_content.dart`) and a three-way text-size multiplier (`InstagramTextSize`: small/medium/large, applied to every overlay text element except the fixed-size FSCOMBO wordmark). Defaults: name/quantity/sequence on, difficulty/rating off (difficulty defaulted on originally; changed to off after initial manual testing showed a quieter default overlay read better). A nameless combo (same fallback convention as the rest of the app — see "Tricks API" above) always shows its trick sequence instead of a title, and the Name toggle becomes non-interactive since there's nothing to hide. The chip list shows the entire trick sequence up to 20 tricks before collapsing to a "+N more" summary — deliberately generous, since the app's own random-unset-field default range only goes up to 20 (see "Unset-field resolution during generation" above).

The same `InstagramOverlay` widget instance renders both the live on-screen preview (`instagram_share_sheet.dart`) and the actual export — `RenderRepaintBoundary.toImage(pixelRatio: 1080/220)` rasterizes the fixed 220×391-logical-pixel canvas to ~1080×1920 real pixels, entirely client-side (no server round-trip, works offline). See `docs/superpowers/specs/2026-09-08-instagram-share-design.md` for the full design rationale.

The picker sheet's action row has two buttons: **Add to Story** (the flow described above) and **Save Image** — captures the same PNG and writes it to the device's photo library via the `gal` package (`InstagramShareService.saveImage`, `Gal.putImageBytes`) instead of handing it to Instagram, for a person who wants to post manually or share to a different app. Requires `NSPhotoLibraryAddUsageDescription` in `ios/Runner/Info.plist` (add-only photo access, not full library read); a `GalException` with `type == GalExceptionType.accessDenied` surfaces as "Allow Photos access to save the image." — both buttons share the sheet's single `_error` display and are mutually disabled while either is in flight.

**iOS only.** The sticker-share mechanism needs native pasteboard access, not available from a web browser — no web entry point exists or is planned. Android's `instagram-stories://` equivalent hasn't been implemented or verified yet (this app has only shipped iOS so far — see "Production Deployment" below) — tracked as a follow-up, not yet started.

**Save a copy**: a non-owner viewing any combo (via a shared link or normal browsing) sees "Save a copy" (authed) or "Log in to save a copy" (unauthed — saving to "your own account" requires having one). This does **not** call a dedicated copy/fork endpoint — it reuses the existing manual-build screen entirely: the viewed combo's `Tricks` (already carrying `TrickId`/`SubComboId`/`Position`/`StrongFoot`/`NoTouch` per slot) are passed to the create-combo screen (web: React Router `navigate(..., { state: { copyFromTricks, copyFromName } })`; mobile: go_router `extra: CopyFromCombo(...)`, a small model in `core/models/combo.dart`), which pre-fills build mode with those slots so the user can hit Save immediately ("save straight away") or edit first ("edit before saving") — one UI path serves both asks. The resulting combo is a fully independent copy (new id, owned by the saver, `Private` by default) via the normal `POST /api/combos/build` call; the original is untouched.

**iOS Universal Links**: `mobile/ios/Runner/Runner.entitlements` has `com.apple.developer.associated-domains = ["applinks:www.fscombo.com"]`; `web/public/.well-known/apple-app-site-association` (mirrored at `web/public/apple-app-site-association` for older-iOS compatibility) declares `paths: ["/combos/*"]` for App ID `6K8AXR83Y3.com.rafaelffs.freestyleCombo` — nginx serves both as `application/json` (`location = /.well-known/apple-app-site-association` / `location = /apple-app-site-association`, extensionless, no redirects, per Apple's requirements). Deliberately **not** `/share/combos/*` — that path always goes through Safari (needed for the OG-preview redirect to work reliably; a client-side JS redirect to a Universal-Link-eligible URL doesn't reliably re-trigger app-opening), then self-heals to the in-app-openable `/combos/{id}` on the next hop. The `ASSOCIATED_DOMAINS` App ID capability was enabled via the ConnectAPI directly (`Spaceship::ConnectAPI::BundleIdCapability.create(bundle_id_id:, capability_type: "ASSOCIATED_DOMAINS")`) rather than the manual Xcode "+Capability" click Sign In with Apple needed — no interactive portal step required this time. **Not yet built/shipped**: per the established lesson (see "iOS release process" below), a capability change requires `fastlane ios setup_signing` to regenerate the provisioning profile before the next build — do that before the first build that needs to test this.

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
- Config: `Auth:Google:Audiences` / `Auth:Apple:Audiences` (comma-separated OAuth client IDs / Apple audiences — see Environment variables table). Google web + iOS client IDs and Apple's audiences (`com.rafaelffs.freestyleCombo` + web Services ID `com.rafaelffs.freestyleCombo.web`) are configured in both `docker-compose.yml` (local) and the production VPS's `/opt/freestylecombo/.env` — confirmed working end-to-end in production via a real TestFlight Google/Apple sign-in. **Android is deliberately not set up yet** (no Google Cloud Android OAuth client, no `mobile/android/app/google-services.json`) — skipped for now, to be created later when Android release work starts.
- Mobile: `google_sign_in` + `sign_in_with_apple` packages, buttons in `SocialSignInButtons` (`mobile/lib/features/auth/social_sign_in_buttons.dart`), shared by `login_screen.dart` and `register_screen.dart`. Apple button is iOS-only (`Platform.isIOS`). `main.dart` calls `GoogleSignIn.instance.initialize(clientId: ...)` on startup with the iOS client ID, only on iOS (`Platform.isIOS ? _googleIosClientId : null`) — Android gets no clientId since it isn't configured yet, so Google sign-in will not work on Android until that setup lands. `ios/Runner/Info.plist` has the reversed iOS client ID registered as a `CFBundleURLTypes` scheme; `ios/Runner.xcodeproj`'s manual signing (`CODE_SIGN_ENTITLEMENTS`, provisioning profile) was regenerated to include the Sign In with Apple capability — verified working live via a real TestFlight sign-in on both providers.
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

**Optional fields and field order (preference form + generate-mode "Custom" panel, web + mobile):** `ComboLength`, `MaxDifficulty`, `StrongFootPercentage`, `NoTouchPercentage`, `MaxConsecutiveNoTouch`, `MaxHighRevolutionTricks`, and `AllowedRevolutions` are all individually toggleable — off means the field is `null` (or `[]` for `AllowedRevolutions`) in the request, not a specific number. Every numeric field is now optional — there's no longer a mandatory one. On `UserPreference`, `ComboLength`/`MaxDifficulty`/`NoTouchPercentage`/`MaxConsecutiveNoTouch` are `int?` columns (migration `MakePreferenceFieldsOptional`), and `StrongFootPercentage` followed the same path one iteration later (migration `MakeStrongFootPercentageOptional`, added after initial user testing surfaced it as an inconsistent-looking exception); `MaxHighRevolutionTricks`/`AllowedRevolutions` were already optional-capable. On `GenerateComboOverrides` every one of these fields was *already* fully nullable/optional on both platforms — the generate screen needed no backend changes for any of this. Web labels these two fields `Strong Foot (%)` / `No-Touch (%)` (mobile: `Strong foot (%)` / `No-touch (%)`) — cosmetic only, no effect on the unrelated per-trick "No touch" toggle in the manual build tab or the summary stat-tile labels.

**Unset-field resolution during generation (`GenerateComboHandler.cs`/`PreviewComboHandler.cs`):** when a field has no override and no saved-preference value, the handler rolls a fresh random value for that generation only — nothing is persisted, so an "everything off" combo/preview comes out varied instead of always hitting the same fixed numbers, and calling again produces a different roll. Ranges (all inclusive): `ComboLength` 5–20, `MaxDifficulty` 4–8, `StrongFootPercentage` 40–90%, `NoTouchPercentage` 5–50%, `MaxConsecutiveNoTouch` 4–10, `MaxHighRevolutionTricks` 1–3. `AllowedRevolutions` and `AllowedTrickIds` keep their existing "empty = no restriction" meaning when unset — there's no sensible random range for either.

Field order on both forms: Name → **Allowed tricks** → Combo length → Revolutions → Strong foot → No-touch → Max consecutive no-touch → Max 3+ rev tricks → Max difficulty → Include cross-overs → Include knee tricks (**default now off**, was on). A brand-new preference or a fresh "Custom" generate selection starts with **every** toggleable field off — the user opts into each one explicitly rather than starting from a fully-populated form (also added after initial testing: the first version of this feature defaulted them on). Web: `OptionalField` (`web/src/components/ui/optional-field.tsx`) wraps each toggleable field with a checkbox that shows/hides it; "off" is `null`/`[]` on `PreferencesPage.tsx` (a saved preference's fields), and `undefined` (the override key omitted) on `CreateComboPage.tsx`'s generate panel — `DEFAULTS`/`GENERATE_DEFAULTS` carry `null`/omitted values for every toggleable field. Mobile: `_OptionalField` (duplicated per-file per this codebase's existing per-screen-private-widget convention) wraps each field with a `CupertinoSwitch`, reusing the existing sliders with a new `showLabel: false` param (added to `_PrefSlider`/`_AppSlider`/`_PrefRangeSlider`/`_AppRangeSlider`) so the label isn't shown twice — every `_XEnabled` state flag defaults to `false`. On the generate screen, a toggle's enabled/onChanged reflects and locks to the *selected preset's* own null-ness when one is selected, matching every other field's existing locked-preset pattern — **except Combo length** (see below), the one field that stays free regardless of preset selection.

**Combo length is never locked on the generate screen, even with a preset selected** — every other field mirrors/locks to the selected preset's own value, but combo length always starts from the preset's value (or the field's normal off-state if the preset has it off) and stays user-editable, so a generation can use a saved preset's other settings with a one-off different length. Web: `CreateComboPage.tsx`'s combo-length `OptionalField`/`Input` are wired to `overrides.comboLength` unconditionally (not gated on `selectedPref`), with a `useEffect` on `selectedPrefId` that resets `overrides.comboLength` to the newly-selected preset's value (or `undefined` for Custom/no preset); the preview call sends `{ comboLength: overrides.comboLength }` as `Overrides` alongside `PreferenceId` when a preset is selected and that value is set, instead of omitting `Overrides` entirely. Mobile: `create_combo_screen.dart`'s combo-length `_OptionalField`/`_AppSlider` use `_comboLengthEnabled`/`_comboLength` directly instead of the `locked ? null : ...` pattern every other field uses (`_comboLength`/`_comboLengthEnabled` are still seeded from the preset in the preset chip's `onTap`, same as before); `_preview()` sends `GenerateComboOverrides(comboLength: _comboLength)` when a preset is selected and combo length is enabled, instead of `overrides = null`. Both platforms rely on `GenerateComboHandler.cs`/`PreviewComboHandler.cs`'s existing `Overrides?.X ?? SavedPref?.X ?? <fallback>` chain — sending `PreferenceId` plus a partial `Overrides` containing only `ComboLength` was already supported, no backend change needed.

`AllowedTrickIds` (`List<Guid>`, default empty) restricts combo generation/preview to only these tricks — an empty list means no restriction (full trick pool). Applied in Step 1 pool filtering, after the `AllowedRevolutions` filter: `Overrides?.AllowedTrickIds ?? SavedPref?.AllowedTrickIds ?? []`, only applied `.Where(t => allowedTrickIds.Contains(t.Id))` when non-empty. No validator rule (no existence check, same leniency as `AllowedRevolutions`). Web: `PreferencesPage` has a collapsible `TrickPicker` (search + checkbox list, lazy-loaded via `tricksApi.getAll()`, filtered to non-transition tricks) wired into the preference form only, positioned right after the Name field — not currently exposed in the web generate-mode quick-overrides panel. Mobile: `preferences_screen.dart`'s preference form has an "Allowed tricks (N selected)" row (also right after Name) that opens a bottom-sheet picker (search + `CheckboxListTile` list, lazy-loaded via `ApiClient.instance.getTricks()`, filtered to non-transition tricks). Mobile's `create_combo_screen.dart` generate view ("Custom" base preset) has the same picker row, in the same position, wired to `GenerateComboOverrides.allowedTrickIds` — when a saved preset is selected instead, the row becomes a read-only banner showing the preset's own allowed-trick count instead of an editable control.

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
4. Sequence (`ComboSequencer.Sequence`) — constraint-aware ordering (avoids adjacent high-rev tricks, biases toward a strong opener/closer), **then inserts a transition "combo" trick between any two adjacent tricks whose `CrossOver` differs**
5. Annotate NoTouch — only CrossOver tricks, respecting NoTouchPercentage & MaxConsecutiveNoTouch
6. (Generate only) Call `IComboEnhancerService.EnhanceAsync()` → Claude AI description → save combo

**`ComboLength` is the target FINAL slot count (real tricks + inserted transitions), not just the real-trick count.** Steps 2–4 run inside a bounded retry loop (`GenerateComboHandler.cs`/`PreviewComboHandler.cs`, up to 8 attempts): since transition insertion (Step 4) depends on the final trick order, which isn't known until sequencing runs, each attempt guesses a real-trick count (starting from `ComboLength`), runs the full pipeline, and adjusts the guess by the exact miss if the resulting total doesn't match. This converges within 1–2 attempts for typical short combos; if it never converges exactly, a deterministic fallback trims or pads the closest attempt to guarantee an exact match every time — trimming removes transition entries first (cosmetic only, and it also nudges the strong/weak split back toward target since transitions are always weak-foot), then real tricks from the end if still over; padding appends more real tricks, favoring whichever foot is currently under its target proportion. This guarantee holds for both Generate and Preview. Covered by `GenerateComboHandlerTests.Handle_ComboLengthIsFinalTotal_IncludingInsertedTransitionTricks` (uses a fixture pool that reliably triggers transitions, unlike `TrickFaker.DefaultPool()` which has no `IsTransition` trick and so never exercises this path).

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
- `GET /api/account/me` — returns `ProfileDto { id, userName, email, isAdmin, landedCount }` (auth required). `landedCount` is every combo this user has personally landed, regardless of who owns it or its current visibility (`IUserComboCompletionRepository.GetCompletedComboIdsAsync(userId).Count` — a plain `UserComboCompletions` query with no combo-side filter) — deliberately not derived from `GetMyCombos()`, which only covers combos the user owns and would miss e.g. a public combo built by someone else that this user landed. `PUT /api/account/me` returns the same shape (recomputes `landedCount` too).
- `PUT /api/account/me` — update username/email
- `PUT /api/account/me/password` — change password (requires currentPassword)
- `DELETE /api/account/me` — self-service account deletion (auth required, no admin needed) — deletes the calling user via `UserManager.DeleteAsync`, same EF-cascade behavior as the admin delete endpoint. Required by Apple App Review Guideline 5.1.1(v) (any app with account creation must offer in-app account deletion).
- `GET /api/account/{id}` — public profile `PublicProfileDto { id, userName, email }` (no auth)
- `AccountPage` at `/account` — three sections: edit profile form, change password form, and a "Delete Account" danger-zone section (confirm via `window.confirm`, then clears the token and redirects to `/login`)
- `UserProfilePage` at `/users/:id` — shows username + email with initial avatar
- "by [username]" on ComboCard links to `/users/{ownerId}`

### Admin User Management (`/api/admin/users`) — moderation dashboard
- `GET /api/admin/users` — list all users with `AdminUserDto { id, userName, email, isAdmin, comboCount, createdAt, authProvider }`, sorted **newest registration first** (`CreatedAt DESC`, then `UserName` as tiebreak) — this is the admin's primary way to spot new signups, not an alphabetical directory.
- `PUT /api/admin/users/{id}` — edit username/email
- `PUT /api/admin/users/{id}/password` — reset password (no current password required)
- `PUT /api/admin/users/{id}/role` — `{ isAdmin: bool }` — assign/revoke Admin role
- `DELETE /api/admin/users/{id}` — delete user account (EF cascades handle related data)
- `AppUser.CreatedAt` (`DateTime`, non-nullable, migration `AddCreatedAtToAppUser`) — set explicitly (`DateTime.UtcNow`) in `RegisterHandler`/`ExternalSignInHandler`, the only two places an `AppUser` is created. Existing rows predating the column have no recoverable real registration date, so the migration backfills them to the migration-apply time via Postgres `NOW()` (not `DateTime.MinValue`, which would show as "0001-01-01" in the UI) — treat any pre-migration `CreatedAt` as approximate.
- `AuthProvider` (`"google"` | `"apple"` | `null` for password accounts — see "Google & Apple Sign-In" above) is surfaced in `AdminUserDto` as a lightweight moderation signal (e.g. spotting a batch of same-provider signups).
- `AdminUsersPage` (web, `/admin/users`) and `AdminUsersScreen` (mobile, `/admin/users`) both show: a "N registered users" total count header, a client-side search box (filters the already-fetched list by username/email substring — no new API params), and per-user Joined date + Auth provider alongside the existing Username/Email/Role/Combos columns and Edit/Reset password/Toggle admin/Delete actions. Deliberately minimal (per the design goal: "keep track of new users, reset passwords" — not a full flaggio-style audit log) — no pagination, no server-side search/sort, no activity/last-login tracking.

### ComboCard features
- Shows `combo.name` (bold, above displayText) when present
- Shows `combo.ownerUserName` (not ownerEmail)
- "by [username]" is a link to `/users/{combo.ownerId}` when ownerId is set
- Favourite toggle: heart icon only (no text label), displayed in a top icon row above combo name — calls `addFavourite`/`removeFavourite`, invalidates `['combos']` query
- Visibility is icon-based near actions (owner only): globe icon only (`🌐`) with neutral color for private (click opens confirm modal to submit as public), yellow for pending approval, blue for public
- No Private/Public text badges on combo cards
- Delete button removed from cards; deletion is available on `ComboDetailPage` only (owner or admin)
- Weak-foot tricks shown as `(wf)` (not `wk`)
- Share button (`ComboCard`/`ComboDetailPage`) shown for the owner (any visibility) or anyone when `Public` — see "Combo link sharing" above
- Non-owner viewers get "Save a copy" / "Log in to save a copy" — see "Combo link sharing" above

### Difficulty badge
- No "d" prefix — just the number
- Color-coded: `bg-green-100 text-green-800` (1–4), `bg-yellow-100 text-yellow-800` (5–7), `bg-red-100 text-red-800` (8–10)
- Applied in `CreateComboPage` build mode (trick picker), `TricksPage` (Diff column), `ComboCard`/`ComboDetailPage`
- `TricksPage` no longer shows a "Level" (commonLevel) column in the table
- **Show/hide toggle**: a "Show difficulty" checkbox (`web/src/lib/displayPrefs.ts`, `localStorage` key `fc_show_difficulty`, default shown) on `TricksPage`/`CombosPage` hides every difficulty badge across trick and combo lists/detail/build screens when off — each component reads `getShowDifficulty()` itself (no shared React context; toggling re-renders the page it's on, other pages pick up the new value on their own next mount)

### Trick/combo search
- `TricksPage`, `CreateComboPage`'s build-mode picker, and `ComboDetailPage`'s edit-panel picker all boost an **exact** abbreviation/name match (case-insensitive) to the top of the filtered list, ahead of the existing sort/insertion order — implemented as a stable partition (exact matches, then the rest), not a comparator, so the existing order within each group is preserved
- `CombosPage` already had a debounced (350ms) search box wired to the server (`search` query param on `GET /api/combos/public`/`mine`); Favourites has no search UI (client-only unpaginated list)

### Path alias
`@/` → `web/src/` (configured in `vite.config.ts` + `tsconfig.app.json`)

### API proxy
Dev server proxies `/api/*` and `/share/*` → `http://localhost:5050` (Vite `server.proxy`) — the `/share/*` entry already existed here even though production nginx was missing the equivalent block until the combo-sharing fix (see "Combo link sharing" above).

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

**Live at `https://www.fscombo.com`** — API + web are in production (see `DeploymentPlan/DEPLOYMENT.md` for the original rollout plan). **`1.0.0` is live on the App Store** (`appStoreState=READY_FOR_SALE`, discovered 2026-09-08 — it was `WAITING_FOR_REVIEW` as of 2026-09-03, so it was approved and released sometime in between; there was no explicit "it shipped" checkpoint in this file, so if a future session needs the exact approval date, check App Store Connect's version history directly). A `1.0.1` version was created 2026-09-08 with build 16 attached (`appStoreState=PREPARE_FOR_SUBMISSION`, `releaseType=AFTER_APPROVAL` for auto-release once approved) and is **waiting on a manual "Submit for Review" click** in App Store Connect (Distribution tab → version 1.0.1) — the ASC API refuses to create the submission itself for this app (see "Swapping the in-flight version onto a newer build" below). `1.0.1+16` bundles everything merged since `1.0.0+9`: optional/toggleable preference fields with random unset-field generation, `ComboLength` as the final total including inserted transitions, the Apple Watch companion app, and the admin moderation dashboard (web + mobile). See "Checking App Store submission status" below for how to re-check state in a future session.

`feature/batch-release` (personal reusable combos, various mobile/web fixes, Google/Apple sign-in, release-pipeline fixes) merged to `main` and deployed on 2026-08-31. `feature/mobile-web-fixes` (combo link sharing, the mobile UX round described above) merged to `main` and deployed on 2026-09-03. `GOOGLE_AUTH_AUDIENCES`/`APPLE_AUTH_AUDIENCES` are set in the VPS's `/opt/freestylecombo/.env` (see Environment variables table) — Google and Apple sign-in confirmed working end-to-end against production via a real TestFlight build.

- **Infra**: single Hetzner VPS (`178.104.158.9`, hostname `ubuntu-4gb-nbg1-1`, user `ubuntu` — `ssh ubuntu@178.104.158.9`) running Docker Compose (`docker-compose.prod.yml`: API + Postgres, both bound to `127.0.0.1` only) behind a host Nginx (`nginx/nginx.conf`) doing TLS termination (Let's Encrypt) and reverse-proxying `/api/` to the API container; React `web/dist/` is served as static files from `/var/www/freestylecombo`. App + secrets live in `/opt/freestylecombo/` on the server (`.env` there is gitignored/VPS-only — see Environment variables table for what goes in it).
- **CD**: `.github/workflows/deploy.yml` runs after CI succeeds on `main` — builds the API into a Docker image pushed to GHCR, builds the React app, rsyncs both + nginx config to the VPS over SSH, swaps only the API container (DB untouched), reloads Nginx, then verifies `/api/tricks` responds. Secrets: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`.
- **Mobile release readiness**: `mobile/lib/core/api/api_client.dart`'s `kBaseUrl` points release builds at `https://www.fscombo.com/api` (debug builds still default to localhost — see "API base URL" below). No cleartext/ATS exceptions needed since prod is HTTPS-only.
- **App Store prerequisites now in place**: production backend reachable over HTTPS, `/privacy` and `/terms` pages live, self-service account deletion (`DELETE /api/account/me`, wired into both `AccountPage` (web) and `account_screen.dart` (mobile)) per Apple Guideline 5.1.1(v), real branded app icon (not a placeholder — see "App icon" below) in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`. Apple Developer Program membership is active and paid — Team ID `6K8AXR83Y3` is set (`DEVELOPMENT_TEAM` in `ios/Runner.xcodeproj`, `CODE_SIGN_STYLE = Manual`, written by fastlane's `update_code_signing_settings`). Bundle ID `com.rafaelffs.freestyleCombo` is registered and the App Store Connect app record exists (app id `6806225332`). A demo/review account is seeded on production (`applereview` / see 1Password or ask the account owner — verified live via `/api/auth/login`). TestFlight has an "Internal Testers" group; builds 1–16 are all `VALID` and export-compliance-cleared. Build 6 (`1.0.0+6`) was the first to include Google/Apple sign-in; build 7 (`1.0.0+7`) added the raw-exception-dump fix; build 8 (`1.0.0+8`) replaces the placeholder app icon (see below); build 9 (`1.0.0+9`) adds combo link sharing (needed a `fastlane ios setup_signing` re-run first — its new `com.apple.developer.associated-domains` entitlement wasn't in the provisioning profile yet) plus a round of mobile UX polish; builds 10–14 (`1.0.0+10` through `+14`) shipped the Apple Watch companion app incrementally plus various mobile fixes (see git log on those build-bump commits for specifics — not itemized here); build 15 (`1.0.1+15`) was the first attempt at shipping the optional-preference-fields work but was superseded before submission; build 16 (`1.0.1+16`) is the one actually attached to the pending `1.0.1` App Store version (see above). New builds are uploaded via `fastlane ios beta`, then need `fastlane ios clear_export_compliance` before they're usable in TestFlight (recent builds have come back from Apple's processing already compliance-cleared automatically, but don't assume that — check first). App Store screenshots (6.9" class, 1320×2868, branded) are in `design/appstore-screenshots/marketing/` — unchanged since `1.0.0`, not re-uploaded for `1.0.1`.

**App icon**: `ios/Runner/Assets.xcassets/AppIcon.appiconset/` held Flutter's stock default logo (the blue flying-F mark) through build 7 — despite prior notes here calling it "already in place," it was never actually replaced with real branding, and Apple rejected build 7's App Store submission for it (Guideline 2.3.8, 2026-09-03: "app icons appear to be placeholder icons"). Fixed in build 8 by rendering the app's real brand mark — the purple-gradient tile + white/purple soccer-ball pattern already defined in `web/public/favicon.svg` (the production favicon/PWA icon; `web/src/components/Logo.tsx`'s in-app `AppIcon`/`Football` React components draw a similar but not pixel-identical pattern via parametric SVG math — `favicon.svg`'s hand-tuned static coordinates are the source of truth) — at all 15 required sizes via a Python/Pillow script (no SVG rasterizer was available on the machine; PIL doesn't render SVG directly, so the shapes were redrawn from the SVG's exact polygon/path coordinates: white circle, 6 pentagon patches, 10 quadratic-bezier seams, faint outline, all clipped to the ball's circle, on a 135°-diagonal `#7C6EF0`→`#5B4AD4` gradient background). Rendered as a full-bleed square with no manual corner rounding (iOS applies its own rounded-corner mask; don't pre-round the asset) and no alpha channel (the 1024×1024 App Store marketing icon must be fully opaque — Apple rejects one with transparency). If this ever needs regenerating (e.g. after a rebrand), don't hand-edit 15 PNGs — regenerate from `favicon.svg`'s coordinates the same way.

**Release build pipeline** (credentials, the ship-a-build steps, and four real bugs already fixed) is fully documented in the Mobile section below — see "iOS release process (TestFlight)".
- **Still needed before App Store submission** (steps only the account owner can do, in App Store Connect's web UI — not automatable via fastlane/API without the owner's business sign-off): create an App Store version, attach a TestFlight build, upload the screenshots, fill in listing copy (name/subtitle/description/keywords), complete the age-rating and App Privacy questionnaires, then submit for review. Note: the app has public user-generated content (combo names, usernames) gated by admin approval before going public, but no in-app block/report mechanism — worth a mention in App Review notes or an explicit call on whether Guideline 1.2 requires adding one before submitting.

---

## Mobile — Flutter (Phase 3)

### Tech stack
- **Flutter 3.19+** · **Dart 3.3+** · **go_router** (navigation) · **dio** (HTTP) · **shared_preferences** (token storage) · **google_fonts** (Plus Jakarta Sans + JetBrains Mono, see "Visual design" below) · **share_plus** (native share sheet, combo link sharing)
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

`combos_screen.dart` has a "Landed" filter chip (authed only, next to the Full name/Abbr. toggle — labeled "Landed" in the UI, matching the app's freestyle-football terminology; the underlying concept is still `combo.isCompleted`/`UserComboCompletion` everywhere else, including this doc) that client-side filters whichever tab (All/Public/Mine/Favourites) is active down to `combo.isCompleted`. The chip's label carries a live count for its current state — "All (1000)"/"Landed (200)"/"Not landed (800)" — computed from that tab's own already-loaded item list (mirroring each tab's own filtering: `filterPublic` exclusion on Mine, client-side search matching on All/Favourites) via `_currentTabCounts()`, tracked per tab in `_allItems`/`_publicItems`/`_mineItems`/`_favouritesItems` state as each tab's future resolves. `ComboCard`'s completion toggle now calls `widget.onRefresh?.call()` after marking/unmarking as landed (previously only the favourite toggle did this) so the parent list's cached `isCompleted` — and this filter — stays in sync immediately.

`combos_screen.dart` also has a debounced (350ms) search box (`Search combos…`) — `ApiClient.getPublicCombos`/`getMyCombos` gained a `search` param threading through to the API's existing `search` query param (the API already supported it for web; mobile just never passed it). Favourites tab filters client-side (name/displayText/ownerUserName substring match) since it's a single unpaginated fetch.

`combos_screen.dart` also has a "Filters" chip (next to "Landed", same active/inactive styling) opening a "Filters & Sort" bottom sheet, all applied client-side alongside the existing Landed/search filtering — same `_matchesFilters`/`_applySort` combination used by both `_buildPagedList` and `_buildSimpleList`:
- **No-touch** — a 3-way `All`/`No NT`/`Has NT` toggle (`_NoTouchFilter`) on whether the combo contains any non-transition trick with `noTouch == true` (`_comboHasNoTouch`).
- **Contains tricks** — a multi-select trick picker (search + `CheckboxListTile`, same lazy-loaded-via-`ApiClient.getTricks()`-filtered-to-non-transition-tricks pattern as `preferences_screen.dart`'s "Allowed tricks" picker) that filters combos down to ones containing **every** selected trick (AND, not OR — `_matchesTrickFilter`, matched by `ComboTrickDto.trickId`).
- **Sort by** — `_SortOption`: Default (server/insertion order, no-op), Difficulty (desc), Trick count (desc), Newest first (desc `createdAt` string compare, same technique the "All" tab's merge-sort already used), Rating (desc `averageRating`). Applied client-side after filtering, on top of whatever order the tab's own future/list already had.

The Landed chip's live counts (`_currentTabCounts()`) also apply the no-touch/trick filters (but not the done filter itself, since that's the dimension being counted across) so its All/Landed/Not-landed numbers stay consistent with what's actually visible. The empty-state message (`_filtersEmptyState()`) prefers the done-filter's specific copy ("You haven't landed any of these yet.") when that's the active filter, falling back to a generic "No combos match your filters." when no-touch/trick filters are what's producing zero results.

`account_screen.dart`'s "Landed" stat tile is now tappable (`context.push('/combos', extra: true)` → `CombosScreen(initialDoneOnly: true)`, read via `app_router.dart`'s `state.extra`), landing on the **All** tab (not Mine) with the Landed filter chip pre-applied — `CombosScreen.initState`'s `initialIndex` is 0 when `initialDoneOnly` is true, 2 (Mine) otherwise. The stat itself reads `ProfileDto.landedCount` from `GET /api/account/me` (see "Account & User Profile" above) rather than being derived from `getMyCombos()`, since the count now legitimately includes combos the user doesn't own — "Mine" alone would under-represent it, hence landing on "All" instead.

### combo_card.dart features
- Shows `combo.name` (bold, 17/800) above `displayText` (JetBrains Mono) when present, with a share icon button (top-right, `_IconToggle` reused from the top icon row) in place of the old gradient `DIFF` badge — shown for the owner (any visibility) or anyone when `Public` (`isOwner || visibilityState == 'public'`, matching `combo_detail_screen.dart`'s hero share button gate), opens the same `share_options_sheet.dart` Share Link/Share to Instagram choice sheet used there (see "Share to Instagram" above), with its own `_shareLinkCombo` replicating `combo_detail_screen.dart`'s `_shareLinkCombo` logic (`Share.share` + a `GlobalKey`-derived `sharePositionOrigin` for the iOS popover anchor)
- Shows `combo.ownerUserName` (not ownerEmail) as an indigo "by [username]" link → `/users/{ownerId}` when set
- Top icon row (authed only): favourite toggle, done toggle (+ count), rate button (non-owners only, opens `RateComboDialog`) — small bordered square icon buttons
- Trick chips: `1. ATW` (JetBrains Mono, position in faint), no-touch chips tinted violet; sub-combo chips fall back to `subComboName` if `abbreviation` is null; "+N" overflow chip expands the list inline (existing cap-at-6 logic preserved)
- Footer row (top hairline border): ★ average rating (if any ratings), ✓ done count, spacer, difficulty as small muted mono text ("Diff N", shown when `DifficultyDisplay.show`, moved here from the old top-right badge), visibility tag (Public=blue/Pending=amber/Private=grey) — tappable only when `canActOnVisibility`, same confirm-sheet flow as before
- Weak-foot tricks shown as `·wf`, no-touch as `·nt` — suppressed for transition tricks (e.g. "Combo"), which have no foot/no-touch of their own; same suppression applies in `combo_detail_screen.dart`'s hero/sequence and the web equivalents (`ComboCard.tsx`, `ComboDetailPage.tsx`, `CreateComboPage.tsx`, `TricksPage.tsx`'s reusable-combo expansion, `AdminSubmissionsPage.tsx`). The root cause was the inline "edit combo" screens (mobile `_EditComboScreen`, web `ComboDetailPage.tsx` edit mode) not knowing about `isTransition` at all, unlike the main build flow — both now hide the SF/NT controls for transition slots and normalize away stale flags on load.
- The `TrickNameDisplay.showFullName` toggle (full name vs. abbreviation, global static flag) was previously only settable from `combos_screen.dart`'s header, and `combo_detail_screen.dart`'s SEQUENCE list ignored it entirely — trick rows there always hardcoded `t.name`. `combo_detail_screen.dart` now has its own Full name/Abbr. chip pair next to the "SEQUENCE" header (same flag, same styling as `combos_screen.dart`'s), and its per-trick label reads `TrickNameDisplay.label(...)` like every other trick-name surface. The nested sub-combo trick-chip list inside an expanded sub-combo step is unaffected — like `combo_card.dart`'s own trick chips, it always shows abbreviations.

### Difficulty chip (mobile)
- Shared `DifficultyChip(int)` in `widgets/difficulty_chip.dart` — green/greenBg (1–4), amber/amberBg (5–7), red/redBg (8–10), JetBrains Mono numeral
- Used in `tricks_screen.dart` rows, `combo_detail_screen.dart` sequence, and `create_combo_screen.dart` trick picker. Combo cards no longer use a `DifficultyChip`-style badge for this — `combo_card.dart`'s difficulty display is now a small "Diff N" mono text in the footer row (see "combo_card.dart features" above); the old gradient `_DiffBadge` widget was removed when its slot became a share button.
- `tricks_screen.dart` subtitle still doesn't show common level (`lvl X`)
- **Show/hide toggle**: `DifficultyDisplay.show` (static flag in `difficulty_chip.dart`, same "global static flag" pattern as `TrickNameDisplay.showFullName`) — `DifficultyChip.build()` and `combo_card.dart`'s `_DiffBadge` usage both check it and render `SizedBox.shrink()` when off, so every existing call site is covered with no per-site changes. Toggle chip (speedometer icon) added next to the Full name/Abbr. chips on `tricks_screen.dart` and `combos_screen.dart` (the two *list* screens); since the flag is global, turning it off there also hides difficulty in `create_combo_screen.dart`/`combo_detail_screen.dart` (no separate toggle UI added on those build/edit screens).

### Trick search exact-match ordering (mobile)
`tricks_screen.dart`, `create_combo_screen.dart` (both the build-mode picker and the generate-mode "Allowed tricks" sheet), and `combo_detail_screen.dart`'s edit-picker all boost an exact abbreviation/name match to the top of the filtered list — same stable-partition approach as web (Dart's `List.sort` isn't guaranteed stable, so this is done via `[...where(exact), ...where(!exact)]` rather than a comparator).

### Autocorrect disabled on trick-name inputs
`autocorrect: false, enableSuggestions: false` added to the four mobile text fields that still had Flutter's default (on): `widgets/submit_trick_sheet.dart`'s `_SubmitField` (submit-trick form's Abbreviation/Name), `tricks_screen.dart`'s `_EditDialogField` (admin edit-trick dialog), `create_combo_screen.dart`'s `_SearchField` (build-mode picker search), `combo_detail_screen.dart`'s edit-picker search field. The two dedicated trick-library search boxes (`tricks_screen.dart` main search, `create_combo_screen.dart`'s allowed-tricks sheet search) already had it disabled.

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

### iOS release process (TestFlight)

**Credentials are pre-configured, no manual export needed.** `mobile/fastlane/.env` (gitignored — covered by `mobile/.gitignore`'s `fastlane/.env*`) holds `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_FILEPATH` for the `fscombo`-named App Store Connect API key (App Store Connect → Users and Access → Integrations — there are two other keys there, `flaggio-release-cli` and an Expo/EAS one, both unrelated to this project, don't touch them). Fastlane auto-loads this file; running any `fastlane ios <lane>` from `mobile/` just works. The actual `.p8` private key file lives at `~/.appstoreconnect/private_keys/AuthKey_JCQFFW5T96.p8`, outside the repo — if credentials ever need rotating, generate a new key on that same page and update both the `.env` file and this note.

**To ship a new build:**
1. Bump the build number in `mobile/pubspec.yaml` (`version: 1.0.0+N` → `+(N+1)`) — TestFlight rejects a re-upload of an already-used build number.
2. `cd mobile && fastlane ios build` — builds a release IPA. Doesn't need ASC credentials (only `beta`/`setup_signing` do) — just the local signing keychain, unlocked non-interactively via `ensure_ci_keychain`.
3. `fastlane ios beta` — uploads the IPA to TestFlight via the ASC API.
4. `fastlane ios clear_export_compliance` — answers "no non-exempt encryption" for any build still missing it; without this a build sits uploaded but isn't installable by testers.
5. Only run `fastlane ios setup_signing` when a capability/entitlement actually changed (e.g. adding a new Sign In with Apple–style capability) — it regenerates the distribution cert + provisioning profile from Apple's servers, unnecessary for a routine build and slower than skipping it.

**Checking App Store submission status**: `fastlane ios check_version_status` reports the actual App Store (not TestFlight) version state via `app.get_app_store_versions(...)` — the correct Spaceship ConnectAPI call is an instance method on the fetched `app` (mirrors `get_beta_groups` in `check_builds`); the class method `Spaceship::ConnectAPI::AppStoreVersion.all` does not exist and will raise `NoMethodError`. Prints `appStoreState`/`appVersionState`, review-detail contact, and whether an `AppStoreVersionSubmission` object exists (a non-null one confirms the submission itself went through — if Agreements/Tax/Banking were unsigned, submission would fail outright rather than reach `WAITING_FOR_REVIEW`). Confirmed 2026-09-01: build `1.0.0` sat at `appStoreState=WAITING_FOR_REVIEW` with a valid submission — this is normal Apple review-queue wait time, not a blocker requiring any manual signature/review action.

**Important**: Apple review approves a specific *build*, not "whatever's on `main`" — code committed/built after a version was submitted is not included until a new build is attached and resubmitted. Check which build is actually attached to the in-flight version before assuming "latest" is what's under review: `Spaceship::ConnectAPI::Build.all(app_id:, build_number:)` (note: `build_number:`, not `filter: { version: }` — the latter raises `ArgumentError: unknown keyword: :filter`), or via `app.get_app_store_versions(includes: "build")` and read `.build.version` on each result.

**Swapping the in-flight version onto a newer build**: `fastlane ios resubmit_for_review build:N` (`mobile/fastlane/Fastfile`) deletes the existing `AppStoreVersionSubmission` (pulls the version back to `PREPARE_FOR_SUBMISSION` so it's editable — confirmed this works even while `appStoreState=WAITING_FOR_REVIEW`, despite the `canReject` field not actually being populated in the API response so it can't be checked beforehand; just attempt the delete and rescue the real error if Apple rejects it), then PATCHes the version's `build` relationship to the target build via `Spaceship::ConnectAPI.patch_app_store_version_with_build`. **It stops there and does not call `POST appStoreVersionSubmissions`** — that endpoint is flatly rejected by the ASC API for this app (`"does not allow 'CREATE'. Allowed operation is: DELETE"`), confirmed not fixable via a different request shape. After running this lane, the actual "Submit for Review" click has to happen manually in App Store Connect (Distribution tab → the version → Submit for Review) — same as the original submission of build 5 was presumably done. Used 2026-09-01 to swap the in-review `1.0.0` version off build 5 (which predated Google/Apple sign-in — Apple would have approved and shipped an app missing that feature) onto build 7 (adds the raw-exception-dump fix on top of build 6's Google/Apple sign-in). Used again 2026-09-03 to swap onto build 9 (combo link sharing + the mobile UX round) — the first attempt right after `fastlane ios beta` finished uploading failed with `"A relationship value is not acceptable for the current resource state. - The specified pre-release build could not be added"` because the build hadn't fully finished Apple's processing yet even though `check_builds` already showed `processingState=VALID`; re-running the same lane ~30s later (it safely skips the submission-delete step when there's nothing to delete) succeeded.

**Creating a brand-new version (when the previous one already shipped)**: `resubmit_for_review` only works when a version is already "in-flight" (exists in an editable/review state) — once a version reaches `READY_FOR_SALE`, there's nothing to swap onto and `app.get_app_store_versions(...).first` would return that already-released version instead. For this case use `fastlane ios create_and_attach_version app_version:X.Y.Z build_number:N` — runs `deliver` (`skip_screenshots: true`, `skip_binary_upload: true`, `automatic_release: true`) to create the new version and push text metadata/release notes, **then** separately PATCHes the build attachment via the same `Spaceship::ConnectAPI.patch_app_store_version_with_build` call `resubmit_for_review` uses — confirmed necessary: `deliver`'s own `build_number:` param did not actually attach the build for a brand-new version (the version came back with no build attached despite `deliver` reporting success). Verify with `check_version_status`, which now also prints `build=` per version. Then `fastlane ios submit_version_for_review app_version:X.Y.Z` attempts the actual submission and always falls back to the same manual-submission instruction as `resubmit_for_review` — confirmed 2026-09-08 that `POST appStoreVersionSubmissions` is rejected for a brand-new version exactly like it is for a resubmission, so this is a blanket restriction for this app, not resubmission-specific. Used 2026-09-08 to create version `1.0.1` and attach build 16 after `1.0.0` went `READY_FOR_SALE`. **`create_and_attach_version` alone is not sufficient to actually pass "Add for Review"** — always follow it with `sync_release_notes_all_locales` and, if the binary embeds the Watch app, `upload_watch_screenshot` (see gotchas 7 and 8 below) before assuming the version is submittable.

**Eight real release-pipeline bugs/gotchas already found and fixed — don't rediscover these:**
1. `flutter build ipa`'s CocoaPods validity check resolves `ruby` via PATH, which by default points at system Ruby, not the Homebrew Ruby CocoaPods (installed via `brew install cocoapods`) actually runs under — falsely reports "CocoaPods not installed or not in valid state" even though `pod --version` works fine directly. Fixed permanently at the top of `mobile/fastlane/Fastfile`: prepends Homebrew's Ruby (`/opt/homebrew/opt/ruby/bin`) to `ENV["PATH"]` for every lane in the file.
2. Xcode's `CODE_SIGN_ENTITLEMENTS` build setting has to actually point at `Runner/Runner.entitlements` in `project.pbxproj` — adding a capability via Xcode's "+Capability" UI creates/updates the entitlements *file* correctly, but this build setting wiring was found missing (a gap from earlier manual project setup, not something Xcode's UI reliably guarantees) and had to be fixed via a `pod install` + `update_code_signing_settings` run, now committed. If a future capability's entitlement silently isn't taking effect, check this setting is still present in `project.pbxproj` before assuming the profile is wrong.
3. `flutter build ipa`'s own default export step doesn't reliably honor manual code signing (the archive step does, correctly; the separate export step is a different code path that doesn't always match) — fixed via an explicit `mobile/ios/ExportOptions.plist` (`signingStyle: manual`, profile named directly) passed through `--export-options-plist` in the `build` lane. Verified by testing a bare `xcodebuild -exportArchive` with the same options directly before wiring it into fastlane.
4. `sigh`'s `output_path` (`~/.appstoreconnect/freestylecombo-signing/`) is **not** the same location `xcodebuild` actually reads provisioning profiles from (`~/Library/MobileDevice/Provisioning Profiles/`, keyed by `<UUID>.mobileprovision`). A regenerated profile sitting only in the former has zero effect on the next build. **Now automated** inside the `setup_signing` lane itself — it installs the regenerated profile into the correct location and removes any other locally-installed profile with the same Name (so a stale duplicate can't win a name-based lookup over the fresh one). No manual profile copying needed as of `62d3ab1`.
5. Flutter's native-assets build (used for pure-Dart-FFI packages like `objective_c`, pulled in transitively by `google_sign_in_ios`) caches its compiled output per package under `.dart_tool/hooks_runner/`, keyed by build config — including target platform. Running any `xcodebuild`/`flutter run`/`flutter build` against an **iOS or watchOS Simulator** destination populates this cache with a Simulator-platform build; a subsequent `flutter build ipa` (device/Release) can then silently **reuse the stale Simulator binary** instead of rebuilding for device — the local build succeeds either way (no error), but Apple's upload validation rejects it: `Invalid executable... references an unsupported platform in the arm64 slice... Simulator platforms aren't permitted` (error 91169). Diagnosable via `otool -l <binary> | grep -A1 LC_BUILD_VERSION` — `platform 7` is Simulator, `platform 2` is device. Fix: `flutter clean` (not just deleting `.dart_tool/hooks_runner` alone — that leaves Xcode's own build-graph pointing at now-deleted hashed paths and the next build fails with a `lipo: can't open input file` error) before rebuilding for device. **Practical rule: never run a Simulator-destination `xcodebuild`/`flutter run` in the same checkout you're about to `flutter build ipa` from without a `flutter clean` in between** — this bit build 12 (Watch simulator testing ran right before the release build).
6. `CFBundleShortVersionString` (the `1.0.0` part of `pubspec.yaml`'s `version:`) must be **strictly higher** than the version of any App Store release that's already been approved — not just any previously-*uploaded TestFlight build*. Discovered 2026-09-08: build 15 (`1.0.0+15`) was rejected by `upload_to_testflight` with `"The value for key CFBundleShortVersionString [1.0.0] ... must contain a higher version than that of the previously approved version [1.0.0]"`, because `1.0.0` had gone `READY_FOR_SALE` on the App Store since the last check in this file (see "Production Deployment" above) — TestFlight enforces this even though the *build number* (`+15`) was still fresh. Fixed by bumping the marketing version to `1.0.1` (build number unchanged) and rebuilding; the same IPA that failed at `1.0.0+15` uploaded fine as `1.0.1+15`. If a TestFlight upload fails with this error, check `fastlane ios check_version_status` for the live App Store version before assuming it's a build-number problem.
7. **The app has two App Store localizations — `en-US` AND `en-GB`** (English U.K.; visible as the default locale selector in the App Store Connect UI) — not just `en-US`, which is the only locale `fastlane/metadata/` has a folder for. `deliver`'s `app_review_information`/version-level calls apply regardless of locale, but anything localization-scoped (What's New / release notes, description, keywords, screenshots) has to be pushed to **both**. Discovered 2026-09-08: `create_and_attach_version` (which runs `deliver` pointed at `fastlane/metadata/en-US/`) left `en-GB`'s What's New empty, and "Add for Review" in the ASC UI blocked with `"English (U.K.) - What's New in This Version - This field is required"` even though the lane had reported success — `deliver` only touches the locales it has local folders for, it does not mirror content across every localization on the version. Fixed with `sync_release_notes_all_locales`, which iterates `version.get_app_store_version_localizations` and calls `.update(attributes: { whatsNew: ... })` directly on each one. **Whenever a new version's listing content changes, verify both locales — not just en-US — before assuming ASC is in sync**, e.g. via `check_version_locales` (What's New) or `check_screenshots` (screenshots, which now also loops every locale, not just en-US).
8. Once a binary embeds the Apple Watch companion app (any build from 10 onward), App Store Connect requires **at least one Apple Watch screenshot** on the version before "Add for Review" will proceed — builds before the Watch app existed (1–9) had no such requirement, so this is easy to forget on the first submission after adding a Watch target. Screenshot size must match one of Apple's known Watch device buckets by exact pixel dimensions (`frameit`'s `device_types.rb` has the table — Ultra is `410×502` or `422×514`; captured via a booted, *paired* iPhone+Watch simulator pair (`xcrun simctl list pairs` — this repo already has one), installing/launching both apps, letting `WatchBridge.swift`'s `WCSession.updateApplicationContext` deliver the JWT so the screenshot shows real logged-in data rather than the "Log in on your iPhone" empty state, then `xcrun simctl io <watch-udid> screenshot <path>.png`. Upload via the new `upload_watch_screenshot path:<file>` lane, which creates the `APP_WATCH_ULTRA` screenshot set per localization (if missing) and calls `AppScreenshotSet#upload_screenshot` directly — deliberately **not** routed through `deliver`'s broader screenshot sync (`skip_screenshots`/`overwrite_screenshots`), since that risks touching the already-correct iPhone/iPad screenshots on either locale. Verify with `check_screenshots` (`state` should read `COMPLETE` with no errors).

**TestFlight always talks to production**, regardless of which git branch/commit built the IPA — see `kBaseUrl` above, hardcoded for release builds. A backend feature that works locally but 404s in a TestFlight build almost always means it hasn't been deployed to production yet, not a client bug — check `curl https://www.fscombo.com/api/<route>` against the same call to local Docker before chasing anything client-side.

**If two Claude sessions (or a session + you in a terminal) are both pointed at this same local checkout**: git working directory state (checked-out branch, uncommitted changes) is shared, not per-session — whichever runs `git checkout <branch>` last wins for both. Confirm which session/branch owns mobile release work before running fastlane commands concurrently with another session.

### Key design decisions
- `AuthService` and `ApiClient` are manual singletons (no DI framework) for simplicity
- `register` returns `201` with no token → app calls `login` immediately after to get the JWT
- `FutureBuilder` pattern used throughout — no Riverpod/BLoC overhead
- `withValues(alpha:)` used instead of deprecated `withOpacity` in Flutter 3.19+

### Apple Watch companion app — offline support

The Watch app (`mobile/ios/Watch App Watch App/`, SwiftUI, see `docs/superpowers/specs/2026-09-03-watch-app-design.md` for its original architecture) caches its last-successful `Public`/`Mine`/`Favourites` fetches to disk (`ComboCacheStore`, a single JSON file in Application Support) and falls back to that cache when a live fetch fails with a network-level error — "All" and "Landed" stay derived client-side from Public+Mine, same as when online. Favourite/landed toggles made while offline apply optimistically to the cache and enqueue a `PendingAction` (`OfflineSyncQueue`, its own JSON file) instead of failing silently; the queue is drained opportunistically — `APIClient`'s success path fires a fire-and-forget flush after every successful call, so no background monitoring or manual "sync" action is needed. `ComboRepository` (`mobile/ios/Watch App Watch App/Offline/`) is the single seam `FilterMenuView`/`ComboListView` go through for all of this instead of calling `APIClient` directly. Both `ComboCacheStore` and `OfflineSyncQueue` are actors (not plain classes) — code review during implementation found that concurrent fetches (`ComboRepository.loadAll()` fetches Public and Mine via `async let`) and concurrent sync-flush triggers could otherwise race on their shared mutable state. A `401` never falls back to cache (an invalid/rotated token can mean the account changed) and a queue flush stops immediately on `401`, marking the existing reconnect state. Logging into a different account on the paired iPhone clears the cache and queue before the new credentials are applied (`WatchAuthStore.apply(context:)`, compares the incoming `userName` against the previously-stored one — credential application is deliberately sequenced to happen only after the clear completes, so a queued old-account action can't get replayed under the new account's token). The Watch App target uses Xcode's `PBXFileSystemSynchronizedRootGroup` — any `.swift` file placed under `mobile/ios/Watch App Watch App/` is automatically included in the build, no `project.pbxproj` editing needed (unlike the Runner/iOS target elsewhere in this project). See `docs/superpowers/specs/2026-09-08-watch-offline-support-design.md` for the full design.

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

234 unit tests covering: nullable/optional preference fields (Create/UpdatePreferencesHandler persisting explicit nulls, GenerateComboHandler resolving a null saved-preference field to a fresh random value within its range — see "Unset-field resolution during generation" above), combo generation/build/preview (including `ComboLength` as final-total-including-transitions — see "Combo generation algorithm" above), combo deletion permissions, `GetComboHandler`'s deliberate lack of a visibility gate (non-owner can view a Private/PendingReview combo by id — see "Combo link sharing"), combo query/update handlers, pending combo review mapping, favourites/completions, auth login/register flows, account/admin handler flows (including `GetUsersHandler`'s newest-first sort and `AuthProvider`/`CreatedAt` fields), trick CRUD handlers, preference CRUD handlers, trick submission review flows, query handlers (tricks/preferences/ratings/pending approvals/submissions), revolution boundary validation (trick create/update/submission — including the half-increment constraint, preference and combo override allowed revolutions, preview override validation, rating score bounds), weight adjustment job/aggregator behavior, reusable combo repository methods, GetTricks unified response, SetReusable endpoint, BuildCombo/UpdateCombo sub-combo slot support, DeleteCombo sub-combo guard, reusable combo visibility guard (cannot be set non-public), personal reusable combos (AddPersonalReusable/RemovePersonalReusable authorization — owner at any visibility, non-owner only on Public, admin bypass on non-Public combos, GetReusableAsync per-user merge including a combo someone else added, BuildCombo/UpdateCombo sub-combo acceptance for whoever added it vs. rejection for anyone who hasn't), and Google/Apple external sign-in (`ExternalSignInHandler` — subject-first match, email fallback with provider/subject backfill onto an existing password account including overwrite-on-second-provider, auto-generated/collision-checked username on new-account creation, invalid-token and no-match-no-email rejection).

---

## Environment variables

| Variable | Where | Description |
|---|---|---|
| `ConnectionStrings__DefaultConnection` | docker-compose / appsettings | PostgreSQL connection |
| `JwtSettings__Secret` | docker-compose / appsettings | Min 32 chars |
| `JwtSettings__Issuer` | docker-compose / appsettings | `FreestyleComboAPI` |
| `JwtSettings__Audience` | docker-compose / appsettings | `FreestyleComboApp` |
| `Auth__Google__Audiences` | docker-compose (local) / production `.env` (VPS-only, gitignored) / appsettings | Comma-separated Google OAuth client IDs (web, iOS, Android) — set both locally and in production (`/opt/freestylecombo/.env`'s `GOOGLE_AUTH_AUDIENCES`); confirmed working end-to-end via a real TestFlight sign-in |
| `Auth__Apple__Audiences` | docker-compose (local) / production `.env` (VPS-only, gitignored) / appsettings | Comma-separated Apple audiences (iOS bundle ID, web Services ID) — same as above, `APPLE_AUTH_AUDIENCES` on the VPS, confirmed working |
| `Anthropic__ApiKey` | docker-compose / appsettings | Claude API key |
| `Resend__ApiKey` | docker-compose / appsettings | Resend API key for forgot-password emails — omit to no-op (logs a warning) instead of sending |
| `Resend__FromAddress` | docker-compose / appsettings | Optional — defaults to `FreestyleCombo <onboarding@resend.dev>` |

---

## GitHub

Repo: `https://github.com/rafaelffs/FreestyleCombo`  
CI: `.github/workflows/ci.yml` — triggers on push to `main` and `feature/**`
