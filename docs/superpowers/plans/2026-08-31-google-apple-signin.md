# Google & Apple Sign-In Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Google Sign-In and Sign in with Apple as additional login methods on FreestyleCombo's Flutter mobile app and React web app, alongside the existing email/username + password login.

**Architecture:** Backend verifies Google/Apple ID tokens directly against each provider's public JWKS (no vendor SDK server-side, ported from the sibling Flaggio project's pattern), then issues FreestyleCombo's existing JWT unchanged (same 7-day single-token model, no refresh tokens). Two new nullable columns on `AppUser` (`AuthProvider`, `ExternalSubject`) track the external identity; sign-in matches by subject first, falls back to email (auto-linking/backfilling), or creates a new account with an auto-generated username. Both clients POST the same `{ idToken }` shape to `POST /api/auth/google` / `POST /api/auth/apple` and handle the response exactly like password login.

**Tech Stack:** ASP.NET Core 10 / MediatR / EF Core (backend), `Microsoft.IdentityModel.Protocols.OpenIdConnect` (JWKS verification), Flutter `google_sign_in` + `sign_in_with_apple` (mobile), Google Identity Services + Apple JS SDK loaded via `<script>` tags, no new npm packages (web).

**Full design context:** `docs/superpowers/specs/2026-08-31-google-apple-signin-design.md` — read it before starting if anything below is unclear.

---

## Prerequisites — read before starting

- Real Google OAuth client IDs and Apple Developer "Sign in with Apple" setup are **prerequisites only the account owner (the user) can create** — Google Cloud Console and Apple Developer portal access, not automatable. Tasks 1–9 (backend + mobile + web code) do **not** require these — they build, compile, typecheck, and unit-test without real credentials. Task 10 (docs) also doesn't need them. **Task 11 is the only task gated on the user supplying real credentials** — do not attempt to test actual sign-in before then.
- Every task ends with a commit. Follow the existing repo's commit message style (see recent `git log`).
- All new backend commands need a matching FluentValidation validator registered via assembly scan (already automatic — `AddValidatorsFromAssembly` in `Program.cs` picks up any `AbstractValidator<T>` in the API project).

---

## File Structure

**Backend — new files:**
- `api/FreestyleCombo.AI/Services/ExternalIdentity.cs`
- `api/FreestyleCombo.AI/Services/IIdTokenVerifier.cs`
- `api/FreestyleCombo.AI/Services/JwksIdTokenVerifier.cs`
- `api/FreestyleCombo.API/Features/Auth/ITokenService.cs`
- `api/FreestyleCombo.API/Features/Auth/TokenService.cs`
- `api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ExternalSignInRequest.cs`
- `api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ExternalSignInCommand.cs`
- `api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ExternalSignInValidator.cs`
- `api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ExternalSignInHandler.cs`
- `api/FreestyleCombo.Tests/Features/ExternalSignInHandlerTests.cs`
- A new EF Core migration (auto-named `AddExternalAuthToUsers`)

**Backend — modified files:**
- `api/FreestyleCombo.Core/Entities/AppUser.cs` — add `AuthProvider`, `ExternalSubject`
- `api/FreestyleCombo.API/Features/Auth/Login/LoginHandler.cs` — use extracted `ITokenService` instead of a private method
- `api/FreestyleCombo.Tests/Features/AuthHandlerTests.cs` — update for `LoginHandler`'s new constructor
- `api/FreestyleCombo.API/Controllers/AuthController.cs` — add `POST /google`, `POST /apple`
- `api/FreestyleCombo.API/Program.cs` — DI registrations
- `api/FreestyleCombo.AI/FreestyleCombo.AI.csproj` — new package reference
- `api/FreestyleCombo.API/appsettings.json` — new config placeholders
- `docker-compose.yml` — new env var placeholders

**Mobile — new files:**
- `mobile/lib/features/auth/social_sign_in_buttons.dart`

**Mobile — modified files:**
- `mobile/pubspec.yaml` — new packages
- `mobile/lib/core/api/api_client.dart` — `signInWithGoogle`/`signInWithApple`
- `mobile/lib/features/auth/login_screen.dart` — wire in the buttons
- `mobile/lib/features/auth/register_screen.dart` — wire in the buttons
- `mobile/ios/Runner/Info.plist` — Google reversed-client-id URL scheme (Task 11, needs the real client ID)

**Web — new files:**
- `web/src/features/auth/SocialSignInButtons.tsx`
- `web/.env.example`

**Web — modified files:**
- `web/src/lib/api/auth.ts` — `signInWithGoogle`/`signInWithApple`
- `web/src/features/auth/LoginPage.tsx` — wire in the component
- `web/src/features/auth/RegisterPage.tsx` — wire in the component
- `web/src/locales/en.json`, `web/src/locales/pt-BR.json` — new `auth.*` keys

**Docs:**
- `CLAUDE.md` — new "Google & Apple Sign-In" subsection, new env vars in the table

---

## Task 1: `AppUser` external-auth columns + migration

**Files:**
- Modify: `api/FreestyleCombo.Core/Entities/AppUser.cs`
- Create: EF migration under `api/FreestyleCombo.Infrastructure/Data/Migrations/`

- [ ] **Step 1: Add the two columns**

In `api/FreestyleCombo.Core/Entities/AppUser.cs`, add inside the class body (after the existing `PasswordResetCodeExpiresAt` property):

```csharp
    // External (OAuth) sign-in — null for password-only accounts. AuthProvider
    // tracks the most recently linked provider ("google" | "apple");
    // ExternalSubject is that provider's `sub` claim. See
    // ExternalSignInHandler for the sign-in/link logic that reads and
    // backfills these onto an existing password account.
    public string? AuthProvider { get; set; }
    public string? ExternalSubject { get; set; }
```

- [ ] **Step 2: Generate the migration**

Run:
```bash
cd api
dotnet ef migrations add AddExternalAuthToUsers --project FreestyleCombo.Infrastructure --startup-project FreestyleCombo.API
```
Expected: two new files created under `FreestyleCombo.Infrastructure/Data/Migrations/` (a `*_AddExternalAuthToUsers.cs` and its `.Designer.cs`), and `AppDbContextModelSnapshot.cs` updated. Open the non-Designer file and confirm it contains `migrationBuilder.AddColumn<string>(name: "AuthProvider", table: "AspNetUsers", ...)` and the same for `ExternalSubject`, both `nullable: true`.

- [ ] **Step 3: Build to confirm no compile errors**

Run: `dotnet build` (from `api/`)
Expected: `Build succeeded.`

- [ ] **Step 4: Commit**

```bash
git add api/FreestyleCombo.Core/Entities/AppUser.cs api/FreestyleCombo.Infrastructure/Data/Migrations/
git commit -m "Add AuthProvider/ExternalSubject columns to AppUser for external sign-in"
```

---

## Task 2: Extract `ITokenService` from `LoginHandler`

This is a pure refactor (no new behavior) so the existing `AuthHandlerTests.cs` Login tests are the safety net — they must still pass unchanged in assertions, only their setup changes.

**Files:**
- Create: `api/FreestyleCombo.API/Features/Auth/ITokenService.cs`
- Create: `api/FreestyleCombo.API/Features/Auth/TokenService.cs`
- Modify: `api/FreestyleCombo.API/Features/Auth/Login/LoginHandler.cs`
- Modify: `api/FreestyleCombo.Tests/Features/AuthHandlerTests.cs`

- [ ] **Step 1: Create `ITokenService`**

```csharp
using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.API.Features.Auth;

public interface ITokenService
{
    (string Token, DateTime ExpiresAt) CreateToken(AppUser user, IList<string> roles);
}
```

- [ ] **Step 2: Create `TokenService`, moving `LoginHandler`'s existing `GenerateToken` logic into it**

```csharp
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using FreestyleCombo.Core.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace FreestyleCombo.API.Features.Auth;

public class TokenService : ITokenService
{
    private readonly IConfiguration _config;

    public TokenService(IConfiguration config) => _config = config;

    public (string Token, DateTime ExpiresAt) CreateToken(AppUser user, IList<string> roles)
    {
        var secret = _config["JwtSettings:Secret"]!;
        var issuer = _config["JwtSettings:Issuer"]!;
        var audience = _config["JwtSettings:Audience"]!;

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email!),
            new(JwtRegisteredClaimNames.UniqueName, user.UserName!),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };
        claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));

        var expiresAt = DateTime.UtcNow.AddDays(7);
        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: expiresAt,
            signingCredentials: creds
        );

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }
}
```

- [ ] **Step 3: Rewrite `LoginHandler` to use it**

Replace the full contents of `api/FreestyleCombo.API/Features/Auth/Login/LoginHandler.cs` with:

```csharp
using FreestyleCombo.API.Features.Auth;
using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Auth.Login;

public class LoginHandler : IRequestHandler<LoginCommand, LoginResponse>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly ITokenService _tokenService;

    public LoginHandler(UserManager<AppUser> userManager, ITokenService tokenService)
    {
        _userManager = userManager;
        _tokenService = tokenService;
    }

    public async Task<LoginResponse> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        var user = await _userManager.FindByEmailAsync(request.Credential)
            ?? await _userManager.FindByNameAsync(request.Credential)
            ?? throw new UnauthorizedAccessException("Invalid credentials.");

        if (!await _userManager.CheckPasswordAsync(user, request.Password))
            throw new UnauthorizedAccessException("Invalid credentials.");

        var roles = await _userManager.GetRolesAsync(user);
        var (token, expiresAt) = _tokenService.CreateToken(user, roles);

        return new LoginResponse(token, expiresAt, user.Id);
    }
}
```

- [ ] **Step 4: Update `AuthHandlerTests.cs`'s Login tests to construct a real `TokenService` instead of passing raw config to `LoginHandler`**

In `api/FreestyleCombo.Tests/Features/AuthHandlerTests.cs`, add this helper next to `CreateJwtConfig()`:

```csharp
    private static ITokenService CreateTokenService() => new TokenService(CreateJwtConfig());
```

Add `using FreestyleCombo.API.Features.Auth;` to the top of the file (for `ITokenService`/`TokenService`).

Then in each of the four `Login_*` test methods, replace `new LoginHandler(userManager.Object, CreateJwtConfig())` with `new LoginHandler(userManager.Object, CreateTokenService())`. Leave every other line (setups, assertions) unchanged — the JWT-claims assertion in `Login_ValidCredentials_ReturnsTokenAndUserId` should keep passing since `TokenService` produces byte-identical tokens to the old inline method.

- [ ] **Step 5: Run the auth tests, confirm they still pass**

Run: `cd api && dotnet test --filter FullyQualifiedName~AuthHandlerTests`
Expected: all `Login_*` and `Register_*` tests pass (same count as before this task).

- [ ] **Step 6: Register `ITokenService` in DI now, not later**

`LoginHandler` is resolved from the DI container at runtime (unlike the tests above, which construct it manually) — if `ITokenService` isn't registered, the app fails at startup the moment `/auth/login` is hit, even though unit tests stay green. Register it now rather than deferring to Task 5, so the app keeps booting correctly after every task.

Add `using FreestyleCombo.API.Features.Auth;` near the other `using FreestyleCombo.*` lines at the top of `api/FreestyleCombo.API/Program.cs`, and add this line in the "AI Services" block (near `builder.Services.AddScoped<IComboEnhancerService, ComboEnhancerService>();`):

```csharp
builder.Services.AddScoped<ITokenService, TokenService>();
```

- [ ] **Step 7: Confirm the app still boots**

```bash
cd /Users/rafael/Projects/FreestyleCombo
docker-compose up -d --build api
sleep 5
curl -s -o /dev/null -w "%{http_code}" http://localhost:5050/api/tricks
```
Expected: `200` (confirms the DI container resolves successfully and the app is serving requests — if `ITokenService` were missing, this would still 200 since `/api/tricks` doesn't touch auth, so also do a quick login smoke test: `curl -s -X POST http://localhost:5050/api/auth/login -H "Content-Type: application/json" -d '{"credential":"nobody","password":"x"}' -w "\nSTATUS:%{http_code}\n"` — expect `STATUS:403` with a clean `{"error":"Invalid credentials."}` body, not a 500 DI-resolution crash).

- [ ] **Step 8: Commit**

```bash
git add api/FreestyleCombo.API/Features/Auth/ITokenService.cs api/FreestyleCombo.API/Features/Auth/TokenService.cs api/FreestyleCombo.API/Features/Auth/Login/LoginHandler.cs api/FreestyleCombo.Tests/Features/AuthHandlerTests.cs api/FreestyleCombo.API/Program.cs
git commit -m "Extract JWT issuance into a shared ITokenService"
```

---

## Task 3: `JwksIdTokenVerifier` — Google/Apple ID token verification

No dedicated unit test for this file — it's thin glue over `Microsoft.IdentityModel`'s well-tested `JsonWebTokenHandler`, and its actual behavior (fails closed on any bad token) is exercised through `ExternalSignInHandler`'s tests in Task 4 via a mocked `IIdTokenVerifier`. This task's own verification is "it compiles."

**Files:**
- Modify: `api/FreestyleCombo.AI/FreestyleCombo.AI.csproj`
- Create: `api/FreestyleCombo.AI/Services/ExternalIdentity.cs`
- Create: `api/FreestyleCombo.AI/Services/IIdTokenVerifier.cs`
- Create: `api/FreestyleCombo.AI/Services/JwksIdTokenVerifier.cs`

- [ ] **Step 1: Add the package**

Run:
```bash
dotnet add api/FreestyleCombo.AI/FreestyleCombo.AI.csproj package Microsoft.IdentityModel.Protocols.OpenIdConnect
```
Expected: `<PackageReference Include="Microsoft.IdentityModel.Protocols.OpenIdConnect" Version="..." />` added to `FreestyleCombo.AI.csproj`'s `PackageReference` `ItemGroup`. Open the csproj afterward and confirm the version resolved is 8.x or newer (compatible with net10.0) — if `dotnet add package` picks something older/incompatible, the build step below will fail with a clear error to fix.

- [ ] **Step 2: `ExternalIdentity` record**

```csharp
namespace FreestyleCombo.AI.Services;

public record ExternalIdentity(string Subject, string? Email, string? DisplayName);
```

- [ ] **Step 3: `IIdTokenVerifier` interface**

```csharp
namespace FreestyleCombo.AI.Services;

public interface IIdTokenVerifier
{
    Task<ExternalIdentity?> VerifyAsync(string provider, string idToken, CancellationToken ct = default);
}
```

- [ ] **Step 4: `JwksIdTokenVerifier` implementation**

```csharp
using System.Collections.Concurrent;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace FreestyleCombo.AI.Services;

// Verifies Google/Apple ID tokens directly against each provider's public
// JWKS — no vendor SDK dependency server-side. Fails closed: any signature,
// issuer, audience, or lifetime problem returns null rather than throwing,
// so callers can turn "not verified" into a clean 403 instead of a 500.
public class JwksIdTokenVerifier : IIdTokenVerifier
{
    private static readonly IReadOnlyDictionary<string, (string MetadataAddress, string[] Issuers)> Providers =
        new Dictionary<string, (string, string[])>
        {
            ["google"] = ("https://accounts.google.com/.well-known/openid-configuration",
                new[] { "accounts.google.com", "https://accounts.google.com" }),
            ["apple"] = ("https://appleid.apple.com/.well-known/openid-configuration",
                new[] { "https://appleid.apple.com" }),
        };

    private static readonly ConcurrentDictionary<string, ConfigurationManager<OpenIdConnectConfiguration>> ConfigManagers = new();

    private readonly IConfiguration _config;
    private readonly ILogger<JwksIdTokenVerifier> _logger;

    public JwksIdTokenVerifier(IConfiguration config, ILogger<JwksIdTokenVerifier> logger)
    {
        _config = config;
        _logger = logger;
    }

    public async Task<ExternalIdentity?> VerifyAsync(string provider, string idToken, CancellationToken ct = default)
    {
        if (!Providers.TryGetValue(provider, out var providerInfo))
            return null;

        var audiencesRaw = _config[$"Auth:{Capitalize(provider)}:Audiences"];
        var audiences = (audiencesRaw ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (audiences.Length == 0)
        {
            _logger.LogWarning("No configured audiences for provider {Provider}; rejecting token.", provider);
            return null;
        }

        var configManager = ConfigManagers.GetOrAdd(provider, _ =>
            new ConfigurationManager<OpenIdConnectConfiguration>(
                providerInfo.MetadataAddress,
                new OpenIdConnectConfigurationRetriever()));

        try
        {
            var openIdConfig = await configManager.GetConfigurationAsync(ct);

            var validationParameters = new TokenValidationParameters
            {
                ValidIssuers = providerInfo.Issuers,
                ValidAudiences = audiences,
                IssuerSigningKeys = openIdConfig.SigningKeys,
                ValidateLifetime = true,
            };

            var result = await new JsonWebTokenHandler().ValidateTokenAsync(idToken, validationParameters);
            if (!result.IsValid)
            {
                _logger.LogWarning(result.Exception, "Rejected {Provider} ID token: invalid.", provider);
                return null;
            }

            if (result.Claims.TryGetValue("sub", out var subObj) && subObj is string subject && !string.IsNullOrWhiteSpace(subject))
            {
                var email = result.Claims.TryGetValue("email", out var emailObj) ? emailObj as string : null;
                var name = result.Claims.TryGetValue("name", out var nameObj) ? nameObj as string : null;
                return new ExternalIdentity(subject, email, name);
            }

            _logger.LogWarning("Rejected {Provider} ID token: missing sub claim.", provider);
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to verify {Provider} ID token.", provider);
            return null;
        }
    }

    private static string Capitalize(string s) => char.ToUpperInvariant(s[0]) + s[1..];
}
```

- [ ] **Step 5: Build**

Run: `cd api && dotnet build`
Expected: `Build succeeded.` If it fails on `JsonWebTokenHandler`/`ValidateTokenAsync` not found, add the package explicitly: `dotnet add api/FreestyleCombo.AI/FreestyleCombo.AI.csproj package Microsoft.IdentityModel.JsonWebTokens` and rebuild — some versions of `Microsoft.IdentityModel.Protocols.OpenIdConnect` pull this in transitively, some don't.

- [ ] **Step 6: Commit**

```bash
git add api/FreestyleCombo.AI/FreestyleCombo.AI.csproj api/FreestyleCombo.AI/Services/ExternalIdentity.cs api/FreestyleCombo.AI/Services/IIdTokenVerifier.cs api/FreestyleCombo.AI/Services/JwksIdTokenVerifier.cs
git commit -m "Add JWKS-based Google/Apple ID token verifier"
```

---

## Task 4: `ExternalSignInHandler` — sign-in / account-linking logic

**Files:**
- Create: `api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ExternalSignInRequest.cs`
- Create: `api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ExternalSignInCommand.cs`
- Create: `api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ExternalSignInValidator.cs`
- Create: `api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ExternalSignInHandler.cs`
- Test: `api/FreestyleCombo.Tests/Features/ExternalSignInHandlerTests.cs`

- [ ] **Step 1: Request DTO, command, validator**

`ExternalSignInRequest.cs`:
```csharp
namespace FreestyleCombo.API.Features.Auth.ExternalSignIn;

public record ExternalSignInRequest(string IdToken);
```

`ExternalSignInCommand.cs`:
```csharp
using FreestyleCombo.API.Features.Auth.Login;
using MediatR;

namespace FreestyleCombo.API.Features.Auth.ExternalSignIn;

public record ExternalSignInCommand(string Provider, string IdToken) : IRequest<LoginResponse>;
```

`ExternalSignInValidator.cs`:
```csharp
using FluentValidation;

namespace FreestyleCombo.API.Features.Auth.ExternalSignIn;

public class ExternalSignInValidator : AbstractValidator<ExternalSignInCommand>
{
    public ExternalSignInValidator()
    {
        RuleFor(x => x.Provider).NotEmpty();
        RuleFor(x => x.IdToken).NotEmpty();
    }
}
```

- [ ] **Step 2: Write the failing tests first**

Create `api/FreestyleCombo.Tests/Features/ExternalSignInHandlerTests.cs`:

```csharp
using FluentAssertions;
using FreestyleCombo.AI.Services;
using FreestyleCombo.API.Features.Auth;
using FreestyleCombo.API.Features.Auth.ExternalSignIn;
using FreestyleCombo.Core.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using FreestyleCombo.Infrastructure.Data;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class ExternalSignInHandlerTests
{
    private static Mock<UserManager<AppUser>> CreateUserManagerMock()
    {
        return new Mock<UserManager<AppUser>>(
            Mock.Of<IUserStore<AppUser>>(),
            null!, null!, null!, null!, null!, null!, null!, null!);
    }

    private static AppDbContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AppDbContext(options);
    }

    private static ITokenService CreateTokenService() => new TokenService(
        new Microsoft.Extensions.Configuration.ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["JwtSettings:Secret"] = "super-secret-key-with-at-least-32-chars",
                ["JwtSettings:Issuer"] = "FreestyleComboAPI",
                ["JwtSettings:Audience"] = "FreestyleComboApp"
            })
            .Build());

    [Fact]
    public async Task NewUser_CreatesAccountWithAutoGeneratedUsername()
    {
        await using var db = CreateDb();
        var userManager = CreateUserManagerMock();
        userManager.SetupGet(m => m.Users).Returns(db.Users);
        userManager.Setup(m => m.FindByEmailAsync("newperson@example.com")).ReturnsAsync((AppUser?)null);
        userManager.Setup(m => m.FindByNameAsync("newperson")).ReturnsAsync((AppUser?)null);
        AppUser? created = null;
        userManager.Setup(m => m.CreateAsync(It.IsAny<AppUser>()))
            .Callback<AppUser>(u => created = u)
            .ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.GetRolesAsync(It.IsAny<AppUser>())).ReturnsAsync([]);

        var verifier = new Mock<IIdTokenVerifier>();
        verifier.Setup(v => v.VerifyAsync("google", "tok", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ExternalIdentity("sub-123", "newperson@example.com", "New Person"));

        var handler = new ExternalSignInHandler(userManager.Object, verifier.Object, CreateTokenService());
        var result = await handler.Handle(new ExternalSignInCommand("google", "tok"), CancellationToken.None);

        result.Token.Should().NotBeNullOrWhiteSpace();
        created.Should().NotBeNull();
        created!.UserName.Should().Be("newperson");
        created.Email.Should().Be("newperson@example.com");
        created.AuthProvider.Should().Be("google");
        created.ExternalSubject.Should().Be("sub-123");
        created.EmailConfirmed.Should().BeTrue();
    }

    [Fact]
    public async Task NewUser_UsernameCollision_AppendsSuffix()
    {
        await using var db = CreateDb();
        db.Users.Add(new AppUser { Id = Guid.NewGuid(), UserName = "newperson", Email = "existing@example.com" });
        await db.SaveChangesAsync();

        var userManager = CreateUserManagerMock();
        userManager.SetupGet(m => m.Users).Returns(db.Users);
        userManager.Setup(m => m.FindByEmailAsync("newperson@example.com")).ReturnsAsync((AppUser?)null);
        userManager.Setup(m => m.FindByNameAsync("newperson")).ReturnsAsync(db.Users.First());
        userManager.Setup(m => m.FindByNameAsync("newperson2")).ReturnsAsync((AppUser?)null);
        AppUser? created = null;
        userManager.Setup(m => m.CreateAsync(It.IsAny<AppUser>()))
            .Callback<AppUser>(u => created = u)
            .ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.GetRolesAsync(It.IsAny<AppUser>())).ReturnsAsync([]);

        var verifier = new Mock<IIdTokenVerifier>();
        verifier.Setup(v => v.VerifyAsync("google", "tok", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ExternalIdentity("sub-456", "newperson@example.com", null));

        var handler = new ExternalSignInHandler(userManager.Object, verifier.Object, CreateTokenService());
        await handler.Handle(new ExternalSignInCommand("google", "tok"), CancellationToken.None);

        created!.UserName.Should().Be("newperson2");
    }

    [Fact]
    public async Task ReturningUser_MatchesBySubject()
    {
        await using var db = CreateDb();
        var existing = new AppUser { Id = Guid.NewGuid(), UserName = "rafael", Email = "rafael@example.com", AuthProvider = "google", ExternalSubject = "sub-789" };
        db.Users.Add(existing);
        await db.SaveChangesAsync();

        var userManager = CreateUserManagerMock();
        userManager.SetupGet(m => m.Users).Returns(db.Users);
        userManager.Setup(m => m.GetRolesAsync(existing)).ReturnsAsync([]);

        var verifier = new Mock<IIdTokenVerifier>();
        // No email on this token — matches how Google/Apple omit it after the first grant.
        verifier.Setup(v => v.VerifyAsync("google", "tok", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ExternalIdentity("sub-789", null, null));

        var handler = new ExternalSignInHandler(userManager.Object, verifier.Object, CreateTokenService());
        var result = await handler.Handle(new ExternalSignInCommand("google", "tok"), CancellationToken.None);

        result.UserId.Should().Be(existing.Id);
        userManager.Verify(m => m.CreateAsync(It.IsAny<AppUser>()), Times.Never);
    }

    [Fact]
    public async Task ExistingPasswordAccount_AutoLinksByEmail()
    {
        await using var db = CreateDb();
        var existing = new AppUser { Id = Guid.NewGuid(), UserName = "rafael", Email = "rafael@example.com" };
        db.Users.Add(existing);
        await db.SaveChangesAsync();

        var userManager = CreateUserManagerMock();
        userManager.SetupGet(m => m.Users).Returns(db.Users);
        userManager.Setup(m => m.FindByEmailAsync("rafael@example.com")).ReturnsAsync(existing);
        userManager.Setup(m => m.UpdateAsync(existing))
            .Callback<AppUser>(u => { existing.AuthProvider = u.AuthProvider; existing.ExternalSubject = u.ExternalSubject; })
            .ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.GetRolesAsync(existing)).ReturnsAsync([]);

        var verifier = new Mock<IIdTokenVerifier>();
        verifier.Setup(v => v.VerifyAsync("apple", "tok", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ExternalIdentity("apple-sub-1", "rafael@example.com", null));

        var handler = new ExternalSignInHandler(userManager.Object, verifier.Object, CreateTokenService());
        var result = await handler.Handle(new ExternalSignInCommand("apple", "tok"), CancellationToken.None);

        result.UserId.Should().Be(existing.Id);
        existing.AuthProvider.Should().Be("apple");
        existing.ExternalSubject.Should().Be("apple-sub-1");
        userManager.Verify(m => m.CreateAsync(It.IsAny<AppUser>()), Times.Never);
    }

    [Fact]
    public async Task InvalidToken_ThrowsUnauthorizedAccessException()
    {
        var userManager = CreateUserManagerMock();
        var verifier = new Mock<IIdTokenVerifier>();
        verifier.Setup(v => v.VerifyAsync("google", "bad-tok", It.IsAny<CancellationToken>()))
            .ReturnsAsync((ExternalIdentity?)null);

        var handler = new ExternalSignInHandler(userManager.Object, verifier.Object, CreateTokenService());
        Func<Task> act = () => handler.Handle(new ExternalSignInCommand("google", "bad-tok"), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task NoMatchAndNoEmail_ThrowsUnauthorizedAccessException()
    {
        await using var db = CreateDb();
        var userManager = CreateUserManagerMock();
        userManager.SetupGet(m => m.Users).Returns(db.Users);

        var verifier = new Mock<IIdTokenVerifier>();
        verifier.Setup(v => v.VerifyAsync("apple", "tok", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ExternalIdentity("sub-no-email", null, null));

        var handler = new ExternalSignInHandler(userManager.Object, verifier.Object, CreateTokenService());
        Func<Task> act = () => handler.Handle(new ExternalSignInCommand("apple", "tok"), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }
}
```

- [ ] **Step 3: Run the tests, confirm they fail with "type or namespace ExternalSignInHandler could not be found"**

Run: `cd api && dotnet test --filter FullyQualifiedName~ExternalSignInHandlerTests`
Expected: build error — `ExternalSignInHandler` doesn't exist yet.

- [ ] **Step 4: Implement `ExternalSignInHandler`**

```csharp
using FreestyleCombo.AI.Services;
using FreestyleCombo.API.Features.Auth.Login;
using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.API.Features.Auth.ExternalSignIn;

public class ExternalSignInHandler : IRequestHandler<ExternalSignInCommand, LoginResponse>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly IIdTokenVerifier _verifier;
    private readonly ITokenService _tokenService;

    public ExternalSignInHandler(UserManager<AppUser> userManager, IIdTokenVerifier verifier, ITokenService tokenService)
    {
        _userManager = userManager;
        _verifier = verifier;
        _tokenService = tokenService;
    }

    public async Task<LoginResponse> Handle(ExternalSignInCommand request, CancellationToken cancellationToken)
    {
        var identity = await _verifier.VerifyAsync(request.Provider, request.IdToken, cancellationToken)
            ?? throw new UnauthorizedAccessException("Invalid or expired sign-in token.");

        var user = await _userManager.Users.FirstOrDefaultAsync(
            u => u.AuthProvider == request.Provider && u.ExternalSubject == identity.Subject,
            cancellationToken);

        if (user == null && !string.IsNullOrWhiteSpace(identity.Email))
        {
            user = await _userManager.FindByEmailAsync(identity.Email);
            if (user != null)
            {
                user.AuthProvider = request.Provider;
                user.ExternalSubject = identity.Subject;
                await _userManager.UpdateAsync(user);
            }
        }

        if (user == null)
        {
            if (string.IsNullOrWhiteSpace(identity.Email))
                throw new UnauthorizedAccessException("Unable to sign in with this account.");

            var userName = await GenerateUniqueUserNameAsync(identity.Email);
            user = new AppUser
            {
                Id = Guid.NewGuid(),
                Email = identity.Email,
                UserName = userName,
                EmailConfirmed = true,
                AuthProvider = request.Provider,
                ExternalSubject = identity.Subject,
            };

            var result = await _userManager.CreateAsync(user);
            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join("; ", result.Errors.Select(e => e.Description)));
        }

        var roles = await _userManager.GetRolesAsync(user);
        var (token, expiresAt) = _tokenService.CreateToken(user, roles);

        return new LoginResponse(token, expiresAt, user.Id);
    }

    private async Task<string> GenerateUniqueUserNameAsync(string email)
    {
        var local = email.Split('@')[0];
        var baseName = new string(local.Where(char.IsLetterOrDigit).ToArray()).ToLowerInvariant();
        if (baseName.Length < 3) baseName = "user";
        if (baseName.Length > 50) baseName = baseName[..50];

        var candidate = baseName;
        var suffix = 2;
        while (await _userManager.FindByNameAsync(candidate) != null)
        {
            candidate = $"{baseName}{suffix}";
            suffix++;
        }

        return candidate;
    }
}
```

- [ ] **Step 5: Run the tests again, confirm they pass**

Run: `cd api && dotnet test --filter FullyQualifiedName~ExternalSignInHandlerTests`
Expected: `Passed! - Failed: 0, Passed: 6, ...`

- [ ] **Step 6: Run the full test suite to confirm nothing else broke**

Run: `cd api && dotnet test`
Expected: all tests pass (previous total + 6 new ones).

- [ ] **Step 7: Commit**

```bash
git add api/FreestyleCombo.API/Features/Auth/ExternalSignIn/ api/FreestyleCombo.Tests/Features/ExternalSignInHandlerTests.cs
git commit -m "Add ExternalSignInHandler: subject-first lookup, email auto-link, auto-generated username on create"
```

---

## Task 5: Wire up the endpoints

**Files:**
- Modify: `api/FreestyleCombo.API/Controllers/AuthController.cs`
- Modify: `api/FreestyleCombo.API/Program.cs`
- Modify: `api/FreestyleCombo.API/appsettings.json`
- Modify: `docker-compose.yml`

- [ ] **Step 1: Add the two endpoints to `AuthController`**

In `api/FreestyleCombo.API/Controllers/AuthController.cs`, add `using FreestyleCombo.API.Features.Auth.ExternalSignIn;` to the top, and add these two actions after the existing `Login` action:

```csharp
    [HttpPost("google")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GoogleSignIn([FromBody] ExternalSignInRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new ExternalSignInCommand("google", request.IdToken), ct);
        return Ok(result);
    }

    [HttpPost("apple")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> AppleSignIn([FromBody] ExternalSignInRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new ExternalSignInCommand("apple", request.IdToken), ct);
        return Ok(result);
    }
```

- [ ] **Step 2: Register `IIdTokenVerifier` in `Program.cs`**

`ITokenService` is already registered (Task 2, Step 6). In the "AI Services" block of `api/FreestyleCombo.API/Program.cs` (near `builder.Services.AddScoped<IComboEnhancerService, ComboEnhancerService>();`), add:

```csharp
builder.Services.AddSingleton<IIdTokenVerifier, JwksIdTokenVerifier>();
```

(`IIdTokenVerifier`/`JwksIdTokenVerifier` are already in scope via the existing `using FreestyleCombo.AI.Services;` at the top of `Program.cs` — no new `using` needed for this one.)

- [ ] **Step 3: Add config placeholders**

In `api/FreestyleCombo.API/appsettings.json`, add a new top-level section after `"JwtSettings"`:

```json
  "Auth": {
    "Google": {
      "Audiences": ""
    },
    "Apple": {
      "Audiences": ""
    }
  },
```

In `docker-compose.yml`, in the `api` service's `environment:` block, add after the existing `JwtSettings__*` lines:

```yaml
      Auth__Google__Audiences: ""
      Auth__Apple__Audiences: ""
```

- [ ] **Step 4: Build and run the full backend test suite**

Run: `cd api && dotnet build && dotnet test`
Expected: `Build succeeded.` and all tests pass.

- [ ] **Step 5: Manual smoke test — confirm the endpoints exist and fail cleanly with no configured audiences**

```bash
docker-compose up -d --build api
sleep 5
curl -s -X POST http://localhost:5050/api/auth/google -H "Content-Type: application/json" -d '{"idToken":"not-a-real-token"}' -w "\nSTATUS:%{http_code}\n"
```
Expected: `STATUS:403` with body `{"error":"Invalid or expired sign-in token."}` (no audiences configured yet → `JwksIdTokenVerifier` returns null → handler throws `UnauthorizedAccessException` → middleware maps it to 403, matching this codebase's existing convention for `UnauthorizedAccessException`, same as a bad password on `/auth/login`).

- [ ] **Step 6: Commit**

```bash
git add api/FreestyleCombo.API/Controllers/AuthController.cs api/FreestyleCombo.API/Program.cs api/FreestyleCombo.API/appsettings.json docker-compose.yml
git commit -m "Wire up POST /api/auth/google and /api/auth/apple endpoints"
```

---

## Task 6: Mobile — packages + `ApiClient` methods

**Files:**
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/lib/core/api/api_client.dart`

- [ ] **Step 1: Add packages**

In `mobile/pubspec.yaml`, under `dependencies:` (after `go_router`), add:

```yaml
  google_sign_in: ^7.0.0
  sign_in_with_apple: ^6.1.3
```

Run: `cd mobile && flutter pub get`
Expected: succeeds, `pubspec.lock` updated. If `google_sign_in` resolves to a version whose API doesn't match `GoogleSignIn.instance.authenticate()` (the v7+ singleton API used in Task 7) — check the resolved version's changelog on pub.dev and adapt Task 7's widget code to whatever API actually landed (v6.x uses `GoogleSignIn().signIn()` on a constructed instance instead).

- [ ] **Step 2: Add `signInWithGoogle`/`signInWithApple` to `ApiClient`**

In `mobile/lib/core/api/api_client.dart`, add these two methods directly after the existing `login` method:

```dart
  Future<({String token, String userId})> signInWithGoogle(String idToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/google',
        data: {'idToken': idToken},
      );
      final d = res.data!;
      return (
        token: d['token'] as String,
        userId: d['userId'] as String,
      );
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<({String token, String userId})> signInWithApple(String idToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/apple',
        data: {'idToken': idToken},
      );
      final d = res.data!;
      return (
        token: d['token'] as String,
        userId: d['userId'] as String,
      );
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }
```

- [ ] **Step 3: Analyze**

Run: `cd mobile && flutter analyze lib/core/api/api_client.dart`
Expected: no new errors (pre-existing style infos are fine).

- [ ] **Step 4: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/core/api/api_client.dart
git commit -m "Add google_sign_in/sign_in_with_apple packages and ApiClient methods"
```

---

## Task 7: Mobile — `SocialSignInButtons` widget + wire into login/register

**Files:**
- Create: `mobile/lib/features/auth/social_sign_in_buttons.dart`
- Modify: `mobile/lib/features/auth/login_screen.dart`
- Modify: `mobile/lib/features/auth/register_screen.dart`

- [ ] **Step 1: Build the shared widget**

```dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../theme/app_colors.dart';

/// Google + (iOS-only) Apple sign-in buttons, shared by the login and
/// register screens — both actions hit the same backend endpoints, which
/// transparently create-or-sign-in an account, so there's no separate
/// "register with Google" flow to build.
class SocialSignInButtons extends StatefulWidget {
  final ValueChanged<String> onError;
  final VoidCallback onSignedIn;

  const SocialSignInButtons({
    super.key,
    required this.onError,
    required this.onSignedIn,
  });

  @override
  State<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends State<SocialSignInButtons> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() => _run(() async {
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw Exception('Google did not return a sign-in token.');
        }
        final result = await ApiClient.instance.signInWithGoogle(idToken);
        await AuthService.instance.setCredentials(result.token, result.userId);
        widget.onSignedIn();
      });

  Future<void> _signInWithApple() => _run(() async {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final idToken = credential.identityToken;
        if (idToken == null) {
          throw Exception('Apple did not return a sign-in token.');
        }
        final result = await ApiClient.instance.signInWithApple(idToken);
        await AuthService.instance.setCredentials(result.token, result.userId);
        widget.onSignedIn();
      });

  @override
  Widget build(BuildContext context) {
    final showApple = Platform.isIOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('or', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted)),
            ),
            const Expanded(child: Divider(color: AppColors.line)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.g_mobiledata, size: 26, color: AppColors.ink),
            label: Text('Continue with Google',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
        ),
        if (showApple) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: SignInWithAppleButton(
              onPressed: _busy ? () {} : _signInWithApple,
              style: SignInWithAppleButtonStyle.black,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Wire into `login_screen.dart`**

In `mobile/lib/features/auth/login_screen.dart`, add the import:

```dart
import 'social_sign_in_buttons.dart';
```

Extract the post-login "pending combo" logic (currently inline in `_submit`, lines handling `AuthService.instance.setCredentials` through `context.go('/combos')`) into a reusable method so both password login and social login share it. Replace the body of `_submit` from `await AuthService.instance.setCredentials(...)` through the end of the `try` block with a call to a new `_onSignedIn()` method, and add that method:

```dart
  Future<void> _onSignedIn() async {
    final pending = AuthService.instance.getPendingCombo();
    if (pending != null) {
      try {
        final tricks = (pending['tricks'] as List).map((t) => BuildComboTrickItem(
          trickId: t['trickId'] as String,
          position: t['position'] as int,
          strongFoot: t['strongFoot'] as bool,
          noTouch: t['noTouch'] as bool,
        )).toList();
        await ApiClient.instance.buildCombo(tricks, pending['isPublic'] as bool, name: pending['name'] as String?);
      } finally {
        await AuthService.instance.clearPendingCombo();
      }
    }
    if (mounted) context.go('/combos');
  }
```

`_submit` becomes:

```dart
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiClient.instance
          .login(_credentialCtrl.text.trim(), _passwordCtrl.text);
      await AuthService.instance.setCredentials(result.token, result.userId);
      await _onSignedIn();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
```

Then add the widget into the `sheet` column, right after the existing `AuthPrimaryButton` (before the "New here?" `Padding`/`Center` block):

```dart
            const SizedBox(height: 18),
            SocialSignInButtons(
              onError: (msg) => setState(() => _error = msg),
              onSignedIn: _onSignedIn,
            ),
```

- [ ] **Step 3: Wire into `register_screen.dart`**

Read `mobile/lib/features/auth/register_screen.dart` in full first (it wasn't shown in this plan's research — the exact `_submit` structure needs confirming before editing) and apply the same pattern as Step 2: extract a shared `_onSignedIn()` helper for the pending-combo-then-navigate logic, call it from both the existing password-registration success path and a new `SocialSignInButtons` placed below the existing submit button, with the same `onError`/`onSignedIn` wiring.

- [ ] **Step 4: Analyze**

Run: `cd mobile && flutter analyze lib/features/auth/`
Expected: no new errors.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/auth/
git commit -m "Add Google/Apple sign-in buttons to login and register screens"
```

---

## Task 8: Web — `authApi` methods + i18n keys

**Files:**
- Modify: `web/src/lib/api/auth.ts`
- Modify: `web/src/locales/en.json`
- Modify: `web/src/locales/pt-BR.json`

- [ ] **Step 1: Add the API methods**

In `web/src/lib/api/auth.ts`, add to the `authApi` object (after `login`):

```ts
  signInWithGoogle: (idToken: string) => api.post<AuthResponse>('/auth/google', { idToken }),
  signInWithApple: (idToken: string) => api.post<AuthResponse>('/auth/apple', { idToken }),
```

- [ ] **Step 2: Add i18n keys**

In `web/src/locales/en.json`, inside the `"auth"` object (after `"loginFailed"`), add:

```json
    "continueWithGoogle": "Continue with Google",
    "continueWithApple": "Continue with Apple",
    "orDivider": "or",
```

In `web/src/locales/pt-BR.json`, inside the equivalent `"auth"` object, add:

```json
    "continueWithGoogle": "Continuar com o Google",
    "continueWithApple": "Continuar com a Apple",
    "orDivider": "ou",
```

(Check the exact key ordering/formatting `pt-BR.json` already uses for the `auth` section and match it — don't assume it's byte-identical in structure to `en.json`.)

- [ ] **Step 3: Typecheck**

Run: `cd web && npx tsc --noEmit -p .`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/api/auth.ts web/src/locales/en.json web/src/locales/pt-BR.json
git commit -m "Add signInWithGoogle/signInWithApple to web authApi"
```

---

## Task 9: Web — `SocialSignInButtons` component + wire into Login/Register

**Files:**
- Create: `web/src/features/auth/SocialSignInButtons.tsx`
- Create: `web/.env.example`
- Modify: `web/src/features/auth/LoginPage.tsx`
- Modify: `web/src/features/auth/RegisterPage.tsx`

- [ ] **Step 1: Build the component**

```tsx
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { authApi, extractError } from '@/lib/api'

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: { client_id: string; callback: (response: { credential: string }) => void }) => void
          renderButton: (parent: HTMLElement, options: Record<string, unknown>) => void
        }
      }
    }
    AppleID?: {
      auth: {
        init: (config: { clientId: string; scope: string; redirectURI: string; usePopup: boolean }) => void
        signIn: () => Promise<{ authorization: { id_token: string } }>
      }
    }
  }
}

function loadScript(id: string, src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (document.getElementById(id)) {
      resolve()
      return
    }
    const script = document.createElement('script')
    script.id = id
    script.src = src
    script.async = true
    script.onload = () => resolve()
    script.onerror = () => reject(new Error(`Failed to load ${src}`))
    document.head.appendChild(script)
  })
}

interface Props {
  onSignedIn: (token: string, userId: string) => void
  onError: (message: string) => void
}

export function SocialSignInButtons({ onSignedIn, onError }: Props) {
  const { t } = useTranslation()
  const googleButtonRef = useRef<HTMLDivElement>(null)
  const [appleReady, setAppleReady] = useState(false)
  const appleClientId = import.meta.env.VITE_APPLE_CLIENT_ID as string | undefined
  const googleClientId = import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined

  useEffect(() => {
    if (!googleClientId) return
    loadScript('google-identity-script', 'https://accounts.google.com/gsi/client')
      .then(() => {
        if (!window.google || !googleButtonRef.current) return
        window.google.accounts.id.initialize({
          client_id: googleClientId,
          callback: async (response) => {
            try {
              const { data } = await authApi.signInWithGoogle(response.credential)
              onSignedIn(data.token, data.userId)
            } catch (err) {
              onError(extractError(err, t('auth.loginFailed')))
            }
          },
        })
        window.google.accounts.id.renderButton(googleButtonRef.current, {
          theme: 'outline',
          size: 'large',
          shape: 'pill',
          text: 'continue_with',
          width: 320,
        })
      })
      .catch(() => onError(t('auth.loginFailed')))
  }, [googleClientId, onError, onSignedIn, t])

  useEffect(() => {
    if (!appleClientId) return
    loadScript('apple-id-script', 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js')
      .then(() => {
        if (!window.AppleID) return
        window.AppleID.auth.init({
          clientId: appleClientId,
          scope: 'name email',
          redirectURI: window.location.origin + '/login',
          usePopup: true,
        })
        setAppleReady(true)
      })
      .catch(() => onError(t('auth.loginFailed')))
  }, [appleClientId, onError, t])

  async function handleAppleSignIn() {
    if (!window.AppleID) return
    try {
      const res = await window.AppleID.auth.signIn()
      const { data } = await authApi.signInWithApple(res.authorization.id_token)
      onSignedIn(data.token, data.userId)
    } catch (err) {
      onError(extractError(err, t('auth.loginFailed')))
    }
  }

  if (!googleClientId && !appleClientId) return null

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <div className="h-px flex-1 bg-gray-200" />
        <span className="text-xs text-gray-400">{t('auth.orDivider')}</span>
        <div className="h-px flex-1 bg-gray-200" />
      </div>
      {googleClientId && <div ref={googleButtonRef} className="flex justify-center" />}
      {appleClientId && appleReady && (
        <button
          type="button"
          onClick={handleAppleSignIn}
          className="flex w-full items-center justify-center gap-2 rounded-full border border-gray-900 bg-black py-2.5 text-sm font-medium text-white hover:bg-gray-800"
        >
          {t('auth.continueWithApple')}
        </button>
      )}
    </div>
  )
}
```

- [ ] **Step 2: `.env.example`**

Create `web/.env.example`:

```
# Google OAuth web client ID (Google Cloud Console) — the Google sign-in
# button is hidden if this is unset.
VITE_GOOGLE_CLIENT_ID=

# Apple Services ID configured for Sign in with Apple on the web — the
# Apple sign-in button is hidden if this is unset.
VITE_APPLE_CLIENT_ID=
```

- [ ] **Step 3: Wire into `LoginPage.tsx`**

In `web/src/features/auth/LoginPage.tsx`, add the import:

```tsx
import { SocialSignInButtons } from './SocialSignInButtons'
```

Add a new piece of state near the top of the component (after `const [password, setPassword] = useState('')`):

```tsx
  const [socialError, setSocialError] = useState<string | null>(null)
```

Add a handler function (after `handleSubmit`):

```tsx
  async function handleSocialSignIn(token: string, userId: string) {
    setToken(token, userId)
    const pending = getPendingCombo()
    if (pending) {
      try {
        await combosApi.build(pending.tricks, pending.isPublic, pending.name)
      } finally {
        clearPendingCombo()
      }
      navigate('/combos')
    } else {
      navigate('/combos/create')
    }
  }
```

In the JSX, inside `<form>`, right after the closing `</Button>` of the submit button and before the `<p className="text-center text-sm text-gray-500">` "no account" line, add:

```tsx
            <SocialSignInButtons onSignedIn={handleSocialSignIn} onError={setSocialError} />
            {socialError && <p className="text-sm text-red-600 text-center">{socialError}</p>}
```

- [ ] **Step 4: Wire into `RegisterPage.tsx`**

Apply the identical pattern from Step 3 to `web/src/features/auth/RegisterPage.tsx` — same import, same `socialError` state, same `handleSocialSignIn` function (it's the same logic; both pages already duplicate the pending-combo-then-navigate block today, so this matches existing duplication rather than introducing a new inconsistency), same JSX placement relative to its own submit button and "already have an account" line.

- [ ] **Step 5: Typecheck**

Run: `cd web && npx tsc --noEmit -p .`
Expected: no errors.

- [ ] **Step 6: Manual browser check (no real credentials needed yet)**

```bash
cd web && npm run dev
```
Open `http://localhost:5173/login` in a browser. Expected: the page loads with no console errors, and — since `VITE_GOOGLE_CLIENT_ID`/`VITE_APPLE_CLIENT_ID` aren't set yet — neither social button renders (confirms the `if (!googleClientId && !appleClientId) return null` guard works and nothing crashes without credentials).

- [ ] **Step 7: Commit**

```bash
git add web/src/features/auth/SocialSignInButtons.tsx web/.env.example web/src/features/auth/LoginPage.tsx web/src/features/auth/RegisterPage.tsx
git commit -m "Add Google/Apple sign-in buttons to web login and register pages"
```

---

## Task 10: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add a new subsection**

In the "API — Key Details" section of `CLAUDE.md`, immediately after the existing "### Forgot / reset password" subsection, add:

```markdown
### Google & Apple Sign-In
`AppUser` has `AuthProvider` (string?, `"google"` | `"apple"` | null) and `ExternalSubject` (string?, the provider's `sub` claim) — null/null for password-only accounts. No separate external-logins table; one row per user.
- `POST /api/auth/google` / `POST /api/auth/apple` — body `{ idToken }`, response identical to `POST /api/auth/login`'s `LoginResponse`. `ExternalSignInHandler` (`FreestyleCombo.API/Features/Auth/ExternalSignIn/`) verifies the token via `IIdTokenVerifier` (`JwksIdTokenVerifier`, `FreestyleCombo.AI/Services/`, verifies against each provider's public JWKS — no vendor SDK), then: matches by `(AuthProvider, ExternalSubject)` first (the only reliable key for returning users, since providers only send `email` on a user's first-ever grant); falls back to matching by `Email` and backfills `AuthProvider`/`ExternalSubject` onto that row if found (this is also how an existing password account gets auto-linked — no separate "link account" endpoint); otherwise creates a new `AppUser` with `EmailConfirmed = true` and a username auto-generated from the email's local-part (uniqueness-suffixed: `rafael`, `rafael2`, ...). Invalid/expired/forged tokens → `403` (same `UnauthorizedAccessException` → middleware mapping as a bad password on `/auth/login`).
- JWT issuance is shared with password login via `ITokenService`/`TokenService` (`FreestyleCombo.API/Features/Auth/`) — same 7-day single-token model as before, no refresh tokens.
- Config: `Auth:Google:Audiences` / `Auth:Apple:Audiences` (comma-separated OAuth client IDs / Apple audiences — see Environment variables table).
- Mobile: `google_sign_in` + `sign_in_with_apple` packages, buttons in `SocialSignInButtons` (`mobile/lib/features/auth/social_sign_in_buttons.dart`), shared by `login_screen.dart` and `register_screen.dart`. Apple button is iOS-only.
- Web: no new npm packages — Google Identity Services and Apple's JS SDK are loaded via injected `<script>` tags in `SocialSignInButtons.tsx` (`web/src/features/auth/`), shared by `LoginPage.tsx`/`RegisterPage.tsx`. Buttons render only when `VITE_GOOGLE_CLIENT_ID`/`VITE_APPLE_CLIENT_ID` are set.
```

- [ ] **Step 2: Add the new env vars to the Environment Variables table**

In `CLAUDE.md`'s "## Environment variables" table, add two rows after the `JwtSettings__Audience` row:

```markdown
| `Auth__Google__Audiences` | docker-compose / appsettings | Comma-separated Google OAuth client IDs (web, iOS, Android) |
| `Auth__Apple__Audiences` | docker-compose / appsettings | Comma-separated Apple audiences (iOS bundle ID, web Services ID) |
```

- [ ] **Step 3: Bump the documented test count**

Run `cd api && dotnet test` and read the final `Passed:` count (should be the pre-existing count + 6 from Task 4). Update the `## Tests` section's opening line (`"223 unit tests covering..."`) to the new total, and append `", and Google/Apple external sign-in (subject-first lookup, email auto-link/backfill, auto-generated username with collision suffixing, invalid-token rejection)"` to the end of that paragraph's list of coverage areas.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Document Google/Apple sign-in in CLAUDE.md"
```

---

## Task 11: MANUAL — real credentials + end-to-end verification

**This entire task is blocked on the user (account owner) and cannot be executed by an agent.** Everything in Tasks 1–10 builds, typechecks, and unit-tests without this — do not attempt to fabricate or guess real client IDs to "complete" this task.

- [ ] **Google Cloud Console** (account owner): create/select a project, configure the OAuth consent screen, create three OAuth 2.0 client IDs — Web application, iOS, Android. For the iOS client, use bundle ID `com.rafaelffs.freestyleCombo`.
- [ ] **Apple Developer** (account owner): on the existing App ID `com.rafaelffs.freestyleCombo`, enable the **Sign in with Apple** capability. Create a Services ID (for the web flow) with an associated key, and configure its return URL to the web app's login page.
- [ ] **Backend config** — set real values (comma-separated if more than one) for `Auth__Google__Audiences` (web + iOS + Android client IDs) and `Auth__Apple__Audiences` (`com.rafaelffs.freestyleCombo` + the web Services ID) in `docker-compose.yml` (local) and production secrets (wherever `JwtSettings__Secret` etc. are currently set for the deployed API — see `DeploymentPlan/DEPLOYMENT.md`).
- [ ] **Web config** — create `web/.env.local` (gitignored) with real `VITE_GOOGLE_CLIENT_ID` (the Web client ID) and `VITE_APPLE_CLIENT_ID` (the Services ID).
- [ ] **iOS config** — in Xcode (`mobile/ios/Runner.xcworkspace`), select the Runner target → Signing & Capabilities → "+ Capability" → **Sign in with Apple** (this creates `ios/Runner/Runner.entitlements` and wires it into the project automatically — do not hand-write this file). Then add the Google iOS client ID's *reversed* form as a URL scheme in `mobile/ios/Runner/Info.plist`, inside a new `CFBundleURLTypes` array (add this as a top-level key alongside the existing ones):
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
      <dict>
          <key>CFBundleURLSchemes</key>
          <array>
              <string>com.googleusercontent.apps.YOUR-IOS-CLIENT-ID-HERE</string>
          </array>
      </dict>
  </array>
  ```
  Replace `YOUR-IOS-CLIENT-ID-HERE` with the iOS client ID's numeric/string identifier reversed (Google Cloud Console shows this exact reversed value on the iOS client's detail page — copy it directly, don't hand-reverse it).
- [ ] **Verify backend**: `curl -X POST http://localhost:5050/api/auth/google -d '{"idToken":"..."}'` with a real ID token obtained by actually signing in through one of the clients below — a bad/placeholder token should still 403; a real one should 200 with a valid JWT.
- [ ] **Verify web**: run `npm run dev`, load `/login`, confirm both buttons render and complete a real sign-in for a brand-new Google account (check a new `AppUser` row was created with the right `AuthProvider`/`ExternalSubject`/auto-generated username) and a returning one.
- [ ] **Verify mobile**: run on a real iOS device or simulator signed into a real Apple ID (Sign in with Apple doesn't work in every simulator config), confirm both buttons work end-to-end, and confirm the Apple button is absent on Android.
- [ ] **Verify auto-link**: sign up with email/password using some test email, then sign in with Google using an account with that same email — confirm it signs into the *same* account (same `userId`) rather than creating a second one.

---

## Self-Review Notes

- **Spec coverage**: every section of the design spec (data model, endpoints, verifier, sign-in/linking logic, username generation, JWT issuance, config, mobile, web, prerequisites, testing) maps to a task above — Tasks 1–5 (backend), 6–7 (mobile), 8–9 (web), 10 (docs), 11 (credentials/manual).
- **Type consistency checked**: `LoginResponse(string Token, DateTime ExpiresAt, Guid UserId)` (Task 5's existing type, reused by `ExternalSignInCommand` in Task 4) is used identically everywhere it's referenced; `ITokenService.CreateToken` returns `(string Token, DateTime ExpiresAt)` and both `LoginHandler` (Task 2) and `ExternalSignInHandler` (Task 4) destructure it the same way; mobile/web `signInWithGoogle`/`signInWithApple` both consistently send `{ idToken }` and read back `{ token, userId }`, matching the existing `login` method's shape exactly.
- **Register screen caveat**: Task 7 Step 3 explicitly tells the implementer to read `register_screen.dart` before editing rather than guessing its `_submit` structure, since it wasn't fully transcribed into this plan — this is a deliberate exception to "no placeholders," not a gap: the file's actual current content is a fact to look up, not a design decision to make.
