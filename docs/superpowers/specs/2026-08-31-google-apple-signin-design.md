# Google & Apple Sign-In — Design

## Summary

Add Google Sign-In and Sign in with Apple as additional login methods on FreestyleCombo's mobile (Flutter) and web (React) clients, alongside the existing email/username + password login. Modeled on the sibling Flaggio project's backend pattern (JWKS-based ID token verification, no vendor SDK dependency on the server), adapted to FreestyleCombo's existing single-JWT auth model — no refresh tokens are introduced.

Apple Sign-In is iOS + web only (no Android), matching Flaggio and satisfying Apple App Review Guideline 4.8 (any app offering third-party/social login must also offer Sign in with Apple) without needing Apple's Android JS flow, which nothing in this app currently requires.

## Backend (ASP.NET Core)

### Data model

Two new nullable columns on `AppUser` (`FreestyleCombo.Core/Entities/AppUser.cs`):

| Column | Type | Notes |
|---|---|---|
| `AuthProvider` | `string?` | `"google"` \| `"apple"` \| null. Null means password-only. Tracks the *most recently linked* external provider — see "Multiple providers, same email" below. |
| `ExternalSubject` | `string?` | The provider's `sub` claim. Null for password-only accounts. |

`PasswordHash` (inherited from `IdentityUser<Guid>`) stays null for accounts that have never set a password — Identity already supports this (`UserManager.HasPasswordAsync` returns false, `CheckPasswordAsync` fails cleanly). No new tables. Migration: `AddExternalAuthToUsers`.

### Endpoints

`POST /api/auth/google` and `POST /api/auth/apple`, both public (no auth required), request body `{ "idToken": "<string>" }`, response identical in shape to `POST /api/auth/login`'s `LoginResponse` (token, expiresAt, userId).

Both route through one `ExternalSignInCommand(string Provider, string IdToken) : IRequest<LoginResponse>` / `ExternalSignInHandler`, mirroring the existing vertical-slice pattern (`FreestyleCombo.API/Features/Auth/ExternalSignIn/`).

### Token verification — `JwksIdTokenVerifier : IIdTokenVerifier`

New service in `FreestyleCombo.AI/Services/` — same layer as `IEmailService`/`ResendEmailService` and `IComboEnhancerService`, the existing home for external-API-calling integrations, keeping `Microsoft.IdentityModel.Protocols.OpenIdConnect` out of `Core`. Directly ports Flaggio's approach:

- Provider table: `google` → `https://accounts.google.com/.well-known/openid-configuration` (issuer `accounts.google.com` or `https://accounts.google.com`); `apple` → `https://appleid.apple.com/.well-known/openid-configuration` (issuer `https://appleid.apple.com`).
- Each provider gets a cached, auto-refreshing `ConfigurationManager<OpenIdConnectConfiguration>` for its JWKS.
- `VerifyAsync(provider, idToken)`: reads valid audiences from config (`Auth:Google:Audiences`, `Auth:Apple:Audiences` — comma-separated, so the one backend accepts tokens from the web, iOS, and Android client IDs), validates signature/issuer/audience via `JsonWebTokenHandler.ValidateTokenAsync`, and on success returns `ExternalIdentity(Subject, Email, DisplayName)` built from `sub`/`email`/`name`.
- Fails closed: any exception, missing `sub`, bad signature, or audience mismatch → `null`, which the handler turns into a 401. Never a 500 for a malformed/expired/forged token.

### Sign-in / account-linking logic — `ExternalSignInHandler`

Directly ports Flaggio's `SignInService.CompleteAsync`:

1. **Subject-first lookup**: find an `AppUser` where `AuthProvider == provider && ExternalSubject == subject`. This is the primary path for every returning user, because Google/Apple only guarantee sending `email` on a user's *first* authorization grant to the app.
2. **Email fallback + backfill**: if no subject match and the token included an email, look up by `Email` alone. If found — whether that account is password-only or was previously linked to a *different* provider — backfill `AuthProvider`/`ExternalSubject` onto it and sign in. This is the "auto-link by email" behavior you chose: an existing password account signing in with Google/Apple for the first time gets transparently linked, no separate UI step.
3. **No match at all**: create a new `AppUser`. Requires an email on the token (true for Google always, and for Apple on a genuine first-ever grant — the only case this branch is reached in, since a returning Apple user without email would already have a subject on file from step 1). Username is auto-generated (see below), `EmailConfirmed = true` (the provider already verified it), `PasswordHash` left null, `AuthProvider`/`ExternalSubject` set from the token.

**Username auto-generation**: take the email's local-part (before `@`), lowercase, strip characters outside `[a-z0-9_]`; if that's empty (or there's no email to derive from — shouldn't happen per the flow above, but defensively falls back to `"user"`), use `"user"`. Check uniqueness against existing usernames (case-insensitive, matching `UserManager`'s default normalization); if taken, append `2`, `3`, ... until free. Same rules `RegisterCommand`'s validator already enforces (max length etc.) apply.

**Multiple providers, same email**: if someone signs up via Google, then later signs in via Apple with the same email, step 2's email fallback finds the same row and *overwrites* `AuthProvider`/`ExternalSubject` with Apple's values. This means the column tracks "most recently used provider," not an exhaustive list — signing in with either provider afterward still works via the email-fallback path (re-backfilling each time), it just means `AuthProvider` alone can't answer "which providers does this user have linked." This is an accepted limitation inherited directly from Flaggio's schema, not something this design tries to solve — a real multi-provider-per-user model would need a separate linking table, which is out of scope here.

### JWT issuance

Unchanged — `ExternalSignInHandler` calls the same token-generation logic `LoginHandler` uses today (same 7-day expiry, same claims including roles). Worth extracting the current `GenerateToken` method out of `LoginHandler` into a small shared `ITokenService` so both handlers call the same code rather than duplicating it.

### Config

New settings, following the existing `JwtSettings__*` env var convention:

| Variable | Description |
|---|---|
| `Auth__Google__Audiences` | Comma-separated Google OAuth client IDs (web, iOS, Android) |
| `Auth__Apple__Audiences` | Comma-separated Apple audiences (iOS bundle ID `com.rafaelffs.freestyleCombo`, web Services ID) |

### Error handling

| Condition | Response |
|---|---|
| Malformed/expired/forged ID token, signature or audience mismatch | `401 { "error": "Invalid token." }` |
| Verified token but no email and no existing subject match (new-account path unreachable) | `401 { "error": "Unable to sign in with this account." }` |
| Any other failure | Falls through to the existing global exception middleware → `500 { "error": "..." }`, same as every other endpoint |

## Mobile (Flutter)

- **Packages**: `google_sign_in` (official Flutter plugin) and `sign_in_with_apple` (community-standard). Different packages than Flaggio's Expo app (`expo-auth-session`, `expo-apple-authentication`) since this is Flutter, not React Native — the backend contract is what's shared, not the client code.
- **UI**: two new buttons on `login_screen.dart`, added below the existing credential form inside `AuthScaffold` (matching its gradient-hero + white-sheet chrome). `sign_in_with_apple`'s button (native `SignInWithAppleButton` widget) only renders when `Platform.isIOS`.
- **Flow**: tap → native SDK returns an ID token → `ApiClient.instance.signInWithGoogle(idToken)` / `signInWithApple(idToken)` → `POST /api/auth/{provider}` → same `LoginResponse` handling as password login (`AuthService.setCredentials`, same JWT decode for `isAdmin`/`userName`, same navigation to `/combos`).
- **iOS setup**: register **Sign in with Apple** capability on the existing App ID `com.rafaelffs.freestyleCombo` in Apple Developer (adds the `com.apple.developer.applesignin` entitlement via Xcode's signing capability, same as `google_sign_in`/`sign_in_with_apple`'s own setup docs describe); add the reversed Google iOS OAuth client ID as a URL scheme in `Info.plist` (`google_sign_in`'s standard setup step).
- **Android**: `google_sign_in` only; no Apple button. Needs the Android OAuth client ID's SHA-1 fingerprint registered in Google Cloud Console.

## Web (React)

- No new npm packages — same as Flaggio, load the providers' own JS SDKs via `<script>` tags: Google Identity Services (`accounts.google.com/gsi/client`, renders Google's own styled button) and Apple's `AppleID` JS SDK (`appleid.cdn-apple.com/.../appleid.auth.js`, custom-styled button per Apple's brand guidelines, popup-based `AppleID.auth.signIn()` flow).
- Wired into `LoginPage.tsx`, calling the same two backend endpoints via `authApi` (`lib/api/auth.ts`), storing the returned token exactly like password login does today.
- Apple's button only renders when a `VITE_APPLE_CLIENT_ID` env var is set (mirrors Flaggio's "button hidden when unset" pattern) — lets Apple's web Services ID be configured independently of/later than the rest.

## Prerequisites (account-owner setup, not automatable)

- **Google Cloud Console**: OAuth consent screen + three client IDs (Web, iOS, Android) in one project.
- **Apple Developer**: enable **Sign in with Apple** on the existing `com.rafaelffs.freestyleCombo` App ID; create a Services ID + a redirect-configured key for the web flow specifically (native iOS doesn't need this part, only web does).

Both are blocking prerequisites — the code can be written and will build/typecheck without them, but no sign-in attempt will actually succeed until real client IDs exist and are set in both the client env vars and the backend's `Auth__*__Audiences` config.

## Testing

- Backend: unit tests for `ExternalSignInHandler` mirroring the existing handler-test patterns (`AddPersonalReusableHandlerTests.cs` etc.) — new-user creation with auto-generated (and uniqueness-suffixed) username, subject-match returning-user path, email-fallback linking to an existing password account, email-fallback re-linking across providers, 401 on verifier returning null. `JwksIdTokenVerifier` itself is thin glue over a well-tested library (`Microsoft.IdentityModel`) — not unit tested directly, covered by the handler tests via a mocked `IIdTokenVerifier`.
- No new mobile/web automated tests planned beyond manual verification (matches this codebase's existing pattern — auth flows aren't currently covered by Flutter/React tests either).
