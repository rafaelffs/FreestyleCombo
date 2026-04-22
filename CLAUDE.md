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
| `Combo` | `Id, OwnerId, Name?, TotalDifficulty, TrickCount, Visibility(ComboVisibility), CreatedAt, AiDescription, ICollection<UserFavouriteCombo>`, `ICollection<UserComboCompletion>` — `IsPublic` is a computed property (`=> Visibility == ComboVisibility.Public`), ignored by EF |
| `ComboTrick` | `Id, ComboId, TrickId, Position, StrongFoot, NoTouch` |
| `ComboRating` | `Id, ComboId, RatedByUserId, Score, CreatedAt` |
| `UserPreference` | `Id, UserId, Name(string max 100), MaxDifficulty, ComboLength, StrongFootPercentage, NoTouchPercentage, MaxConsecutiveNoTouch, IncludeCrossOver, IncludeKnee, AllowedRevolutions(List<decimal>)` — 1:many with AppUser (no unique index on UserId), `AllowedRevolutions` stored as `jsonb` |
| `TrickSubmission` | `Id, Name, Abbreviation, CrossOver, Knee, Revolution, Difficulty, CommonLevel, Status(enum), SubmittedAt, SubmittedById, ReviewedAt?, ReviewedById?` |
| `UserFavouriteCombo` | Composite PK `(UserId, ComboId)`, `CreatedAt` — cascade deletes on both FK |
| `UserComboCompletion` | Composite PK `(UserId, ComboId)`, `CreatedAt` — cascade deletes on both FK. Tracks which users have marked a combo as done (toggle). |

`SubmissionStatus` enum: `Pending = 0`, `Approved = 1`, `Rejected = 2` — stored as int.  
Approving a submission creates a real `Trick` from the submission fields.

`ComboVisibility` enum (in `FreestyleCombo.Core/Entities/Combo.cs`): `Private = 0`, `PendingReview = 1`, `Public = 2` — stored as int column `Visibility` in `Combos` table (default 0). When a user sets a combo public (build or update), it goes to `PendingReview`; an admin approves/rejects it.

### Interfaces (`FreestyleCombo.Core/Interfaces/`)
- `ITrickRepository` (includes `DeleteAsync` — checks ComboTricks before deleting)
- `IComboRepository` (includes `DeleteAsync`, `GetAllByOwnerAsync` — no pagination, includes Owner nav)
- `IComboRatingRepository`, `ITrickSubmissionRepository`
- `IUserPreferenceRepository` — `GetAllByUserIdAsync`, `GetByIdAsync`, `AddAsync`, `UpdateAsync`, `DeleteAsync`
- `IUserFavouriteRepository` — `AddAsync`, `RemoveAsync`, `GetFavouriteComboIdsAsync`, `ExistsAsync`
- `IUserComboCompletionRepository` — `AddAsync`, `RemoveAsync`, `GetCompletedComboIdsAsync`, `ExistsAsync`, `GetCompletionCountsAsync`
- `IComboEnhancerService` — extracted for Moq mockability

### Tricks API (`/api/tricks`)
| Method | Route | Auth | Description |
|---|---|---|---|
| `GET` | `/` | Public | Get all tricks (optional filters: `crossOver`, `knee`, `maxDifficulty`) |
| `PUT` | `/{id}` | Admin | Update trick — all fields editable |
| `DELETE` | `/{id}` | Admin | Delete trick — 409 Conflict if used in any combo |

Trick delete throws `InvalidOperationException` ("This trick is used in X combo(s)...") if any `ComboTrick` references it → middleware returns 400.

### Combos extra endpoints
| Method | Route | Auth | Description |
|---|---|---|---|
| `POST` | `/api/combos/preview` | User | Preview combo (no save, no AI) — returns `PreviewComboResponse { Tricks, Warnings }` |
| `POST` | `/api/combos/build` | User | Build combo manually — accepts optional `name`; no AI description (`AiDescription = null`); sets `Visibility = PendingReview` if `isPublic = true` |
| `PUT` | `/api/combos/{id}` | User/Admin | Update combo (name + tricks) — owner or admin only; if combo was `Public`, resets to `PendingReview` |
| `DELETE` | `/api/combos/{id}` | User/Admin | Owner or Admin can delete; 403 otherwise |
| `POST` | `/api/combos/{id}/favourite` | User | Add combo to favourites |
| `DELETE` | `/api/combos/{id}/favourite` | User | Remove combo from favourites |
| `POST` | `/api/combos/{id}/complete` | User | Mark combo as done (idempotent) |
| `DELETE` | `/api/combos/{id}/complete` | User | Unmark combo as done (idempotent) |
| `GET` | `/api/combos/pending-review` | Admin | List combos pending admin review |
| `POST` | `/api/combos/{id}/approve-visibility` | Admin | Approve → sets `Visibility = Public` |
| `POST` | `/api/combos/{id}/reject-visibility` | Admin | Reject → sets `Visibility = Private` |

`BuildComboCommand` validates: `Tricks` NotEmpty, each `Position >= 1`, NoTouch only on `CrossOver = true` tricks (handler throws `InvalidOperationException` if violated).

`GenerateComboCommand(Guid? PreferenceId, GenerateComboOverrides? Overrides, string? Name)` — `PreferenceId` replaces the old `UsePreferences` bool. When set, the handler fetches that preference by ID and verifies ownership; when null, uses inline `Overrides`. Saved as `null` if Name is blank/whitespace. **No longer generates an AI description** — `AiDescription` is always `null` for new combos.

`PreviewComboCommand(Guid? PreferenceId, GenerateComboOverrides? Overrides)` — runs generation steps 1–5 (filter, split, pick, shuffle, annotate NoTouch). **No AI call, no DB save.** Same `PreferenceId` pattern as GenerateComboCommand.

`UpdateComboCommand(Guid ComboId, string? Name, List<BuildComboTrickItem>? Tricks)` — updates Name and/or replaces trick list. Throws `UnauthorizedAccessException` (→ 403) if caller is not owner or admin.

All combo DTOs (`GenerateComboResponse`, `PublicComboDto`, `MyComboDto`, `ComboDetailDto`) now include `Name?`, `OwnerUserName?`, `IsFavourited`, `IsCompleted`, `CompletionCount`, `Visibility` (string: "Private"/"PendingReview"/"Public"). Combos in `GET /mine` sort favourites first, then by `CreatedAt DESC`.

`GET /api/combos/public` filters by `Visibility == Public` (not `IsPublic`). `UpdatePreferencesHandler` now returns `PreferenceDto` (was `Ok()` with no body).

### Login with username or email
`LoginCommand` field renamed `Email` → `Credential`. Handler tries `FindByEmailAsync` first, then `FindByNameAsync`. Validator uses `NotEmpty` + `MaximumLength(256)` only (no `EmailAddress()` rule).

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
| `Revolution` | 0.5 | **4** | Trick create/update/submission validators |
| `AllowedRevolutions[]` | 0.5 | **4** | Preference + combo override validators |

### Combo generation algorithm
**Preview** (steps 1–5, `POST /api/combos/preview`): no AI, no DB save — returns trick list + warnings.  
**Generate** (all 6 steps, `POST /api/combos/generate`): saves to DB, calls AI for description.

1. Filter trick pool (MaxDifficulty, IncludeCrossOver, IncludeKnee, AllowedRevolutions)
2. Split slots: StrongFoot % → strong slots, rest → weak slots
3. Weighted random pick (weight = `CommonLevel`); fill by position
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
    └── tricks/         # TricksPage (/tricks, public, inline submit form), AdminSubmissionsPage (/admin/approvals)
```

Routes: `/combos` (public, tabbed), `/combos/create` (protected, mode selector), `/admin/approvals` (admin only), `/admin/users` (admin only), `/account` (protected), `/users/:id` (public). Old admin routes `/admin/submissions` and `/admin/combo-reviews` redirect to `/admin/approvals`. Create route remains accessible from the "Create new" button inside `/combos`.

`CreateComboPage` modes: `'choose'` (initial), `'generate'` (calls `/preview` → populates build slots on success), `'build'` (manual slot picker + save). Name field is at the top, shared across all modes. In generate mode: a `<select>` dropdown lists user's saved preferences by name (first option: "Custom"). When a preference is selected, all fields are shown read-only/locked; when "Custom", all fields are editable. Passes `preferenceId` (not the old `usePreferences` bool) to preview API.

`PreferencesPage` shows a list of named preference cards with Edit/Delete per card and a "New preference" button at the top. Create/edit opens an inline form in a new Card. Delete shows a confirm button inline before removing.

`AdminRoute` redirects non-admins to `/combos`. `isAdmin()` decodes the JWT payload (no library, no API call) and checks `ClaimTypes.Role === "Admin"`.

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
- `GET /api/account/{id}` — public profile `PublicProfileDto { id, userName, email }` (no auth)
- `AccountPage` at `/account` — two sections: edit profile form, change password form
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

## Mobile — Flutter (Phase 3)

### Tech stack
- **Flutter 3.19+** · **Dart 3.3+** · **go_router** (navigation) · **dio** (HTTP) · **shared_preferences** (token storage)
- No external state management library — plain `StatefulWidget` + `FutureBuilder`

### Directory structure
```
mobile/lib/
├── main.dart
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
│   ├── auth/                     # login_screen.dart (credential field), register_screen.dart
│   ├── combos/                   # combos_screen.dart (tabbed: Public + Mine),
│   │                             # create_combo_screen.dart (mode: choose/generate/build),
│   │                             # combo_detail_screen.dart (with inline edit for owners)
│   ├── preferences/              # preferences_screen.dart
│   ├── tricks/                   # tricks_screen.dart (/tricks, public, FAB → submit bottom sheet)
│   └── admin/                    # admin_submissions_screen.dart (/admin/approvals)
├── router/app_router.dart        # GoRouter config, auth + admin redirect; initialLocation: /combos
└── widgets/
    ├── main_shell.dart           # Bottom nav: Combos, Tricks, Settings (auth), Admin (admin)
    ├── combo_card.dart           # name display, ownerUserName, fav toggle (icon only, top-left), visibility icon states
    └── rate_combo_dialog.dart    # Star rating AlertDialog
```

`AuthService.isAdmin` decodes the JWT on `setCredentials()` and persists the result in SharedPreferences (`fc_is_admin`). `AuthService.userName` extracts `unique_name` claim from JWT and persists in SharedPreferences (`fc_user_name`). Admin routes (`/admin/*`) are redirect-guarded in the router.

`preferences_screen.dart` shows an **Account card** at the top (username + "Edit profile & password" → `/account`), then a list of `_PrefCard` tiles. FAB opens `_PreferenceForm` in a `showModalBottomSheet`.

`account_screen.dart` at `/account` — two cards: edit username/email form, change password form. Calls `AuthService.instance.setUserName()` on successful username update.

`user_profile_screen.dart` at `/users/:id` — shows username + email with a letter avatar.

`admin_users_screen.dart` at `/admin/users` — ListView of user tiles with PopupMenuButton: Edit (AlertDialog), Reset password (AlertDialog), Toggle admin role, Delete (confirm dialog).

`create_combo_screen.dart` generate view: `_usePrefs` switch replaced with a `DropdownButtonFormField<String?>` (null = Custom, value = preferenceId). Loading preferences via `_loadPreferences()` when entering generate mode. When a preference is selected, its values are copied to the state variables and sliders/switches have `onChanged: null` (read-only). Passes `_selectedPrefId` (not `_usePrefs`) to `previewCombo()`.

### Mobile Navigation (post-merge)
| Index | Label | Route | Auth |
|---|---|---|---|
| 0 | Combos | `/combos` | No |
| 1 | Tricks | `/tricks` | No |
| 2 | Settings | `/preferences` | Yes |
| 3 | Admin | `/admin/approvals` | Admin only |

New mobile routes: `/account` (protected), `/users/:id` (public), `/admin/users` (admin only).

### combo_card.dart features
- Shows `combo.name` (bold) above `displayText` when present
- Shows `combo.ownerUserName` (not ownerEmail)
- "by [username]" is tappable (GestureDetector → `context.push('/users/${combo.ownerId}')`) when ownerId is set, styled as indigo underline
- Favourite toggle: `Icons.favorite` / `Icons.favorite_border` (no text label), displayed in a top icon row above combo name — calls `addFavourite`/`removeFavourite`, triggers `onRefresh`
- Visibility is icon-based near actions (owner only): `Icons.public` only with neutral color for private (click opens confirm modal to submit as public), yellow for pending approval, blue for public
- No Private/Public text chips on combo cards
- Delete button removed from cards; deletion is available on `combo_detail_screen.dart` only (owner or admin)
- Weak-foot tricks shown as `(wf)`

### Difficulty chip (mobile)
- `_DiffChip` widget: colored chip — green.shade100/800 (1–4), yellow.shade100/900 (5–7), red.shade100/800 (8–10)
- Used in `tricks_screen.dart` (trailing) and `build_combo_screen.dart` (trick picker trailing)
- `tricks_screen.dart` subtitle no longer shows common level (`lvl X`)

### Setup (Flutter must be installed first)
```bash
cd mobile

# If no platform folders exist yet, scaffold them:
flutter create . --org com.rafaelffs --project-name freestyle_combo --platforms android,ios,web

flutter pub get
flutter run
```

### API base URL (edit `lib/core/api/api_client.dart`)
- Android emulator: `http://10.0.2.2:5050/api` (default)
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

120 unit tests covering: combo generation/build/preview, combo visibility and deletion permissions, combo query/update handlers, pending combo review mapping, favourites/completions, auth login/register flows, account/admin handler flows, trick CRUD handlers, preference CRUD handlers, trick submission review flows, query handlers (tricks/preferences/ratings/pending approvals/submissions), revolution boundary validation (trick create/update/submission, preference and combo override allowed revolutions, preview override validation, rating score bounds), and weight adjustment job/aggregator behavior.

---

## Environment variables

| Variable | Where | Description |
|---|---|---|
| `ConnectionStrings__DefaultConnection` | docker-compose / appsettings | PostgreSQL connection |
| `JwtSettings__Secret` | docker-compose / appsettings | Min 32 chars |
| `JwtSettings__Issuer` | docker-compose / appsettings | `FreestyleComboAPI` |
| `JwtSettings__Audience` | docker-compose / appsettings | `FreestyleComboApp` |
| `Anthropic__ApiKey` | docker-compose / appsettings | Claude API key |

---

## GitHub

Repo: `https://github.com/rafaelffs/FreestyleCombo`  
CI: `.github/workflows/ci.yml` — triggers on push to `main` and `feature/**`
