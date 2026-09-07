# Optional Preference Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make six preference/generate-override fields individually toggleable (off = not sent, not a specific number), reorder fields on the preference form and the generate screen's "Custom" panel, and flip `IncludeKnee`'s default to off — on both web and mobile.

**Architecture:** `GenerateComboOverrides` (the generate-screen model) is already fully nullable on both platforms — the generate screen needs zero backend changes. The real backend work is making four `UserPreference` columns (`ComboLength`, `MaxDifficulty`, `NoTouchPercentage`, `MaxConsecutiveNoTouch`) nullable (one migration + validator/DTO updates); `MaxHighRevolutionTricks` and `AllowedRevolutions` are already nullable/empty-capable there too. On the frontend, each of the six fields gets a small toggle wrapper (`OptionalField` on web, `_OptionalField` on mobile) that shows/hides the existing slider and drives whether `null`/`[]` or a concrete value is sent.

**Tech Stack:** ASP.NET Core 10 + EF Core + FluentValidation (backend), React + TypeScript (web), Flutter/Dart (mobile).

**Spec:** `docs/superpowers/specs/2026-09-06-optional-preference-fields-design.md`

---

## File Map

| File | Change |
|---|---|
| `api/FreestyleCombo.Core/Entities/UserPreference.cs` | Modify — 4 fields become `int?`, `IncludeKnee` default → `false` |
| New EF Core migration | Create — via `dotnet ef migrations add` |
| `api/FreestyleCombo.API/Features/Preferences/CreatePreference/{CreatePreferenceCommand,CreatePreferenceValidator}.cs`, `CreatePreferenceHandler.cs` | Modify — nullable types + `.When(HasValue)` guards |
| `api/FreestyleCombo.API/Features/Preferences/UpdatePreferences/{UpdatePreferencesCommand,UpdatePreferencesValidator}.cs`, `UpdatePreferencesHandler.cs` | Modify — same |
| `api/FreestyleCombo.API/Features/Preferences/GetPreferences/GetPreferencesQuery.cs` | Modify — `PreferenceDto` nullable types |
| `api/FreestyleCombo.API/Controllers/PreferencesController.cs` | Modify — `PreferenceRequest` nullable types |
| `api/FreestyleCombo.API/Features/Combos/GenerateCombo/GenerateComboHandler.cs`, `.../PreviewCombo/PreviewComboHandler.cs` | Modify — `IncludeKnee` fallback `?? true` → `?? false` |
| `api/FreestyleCombo.Tests/Features/PreferenceHandlerTests.cs`, `GenerateComboHandlerTests.cs` | Modify — new null-field tests |
| `web/src/lib/api/preferences.ts` | Modify — 4 fields become `number \| null` |
| `web/src/components/ui/optional-field.tsx` | Create — shared toggle wrapper |
| `web/src/features/preferences/PreferencesPage.tsx` | Modify — reorder, wrap 6 fields, move Allowed tricks, knee default |
| `web/src/features/combos/CreateComboPage.tsx` | Modify — same, for the generate panel |
| `mobile/lib/core/models/user_preference.dart` | Modify — 4 fields become `int?`, safe `fromJson` casts |
| `mobile/lib/features/preferences/preferences_screen.dart` | Modify — `_OptionalField` widget, `showLabel` param on sliders, reorder, wrap, move picker, knee default |
| `mobile/lib/features/combos/create_combo_screen.dart` | Modify — same, for the generate view |
| `CLAUDE.md` | Modify — document all of the above |

---

### Task 1: Backend entity + migration

**Files:**
- Modify: `api/FreestyleCombo.Core/Entities/UserPreference.cs`

- [ ] **Step 1: Make the four fields nullable, flip `IncludeKnee`'s default**

Find:
```csharp
public class UserPreference
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int MaxDifficulty { get; set; } = 10;
    public int ComboLength { get; set; } = 6;
    public int StrongFootPercentage { get; set; } = 60;
    public int NoTouchPercentage { get; set; } = 30;
    public int MaxConsecutiveNoTouch { get; set; } = 2;
    public bool IncludeCrossOver { get; set; } = true;
    public bool IncludeKnee { get; set; } = true;
    public List<decimal> AllowedRevolutions { get; set; } = [];
```

Replace with:
```csharp
public class UserPreference
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int? MaxDifficulty { get; set; }
    public int? ComboLength { get; set; }
    public int StrongFootPercentage { get; set; } = 60;
    public int? NoTouchPercentage { get; set; }
    public int? MaxConsecutiveNoTouch { get; set; }
    public bool IncludeCrossOver { get; set; } = true;
    public bool IncludeKnee { get; set; } = false;
    public List<decimal> AllowedRevolutions { get; set; } = [];
```

- [ ] **Step 2: Generate the migration**

Run:
```bash
cd api
dotnet ef migrations add MakePreferenceFieldsOptional --project FreestyleCombo.Infrastructure --startup-project FreestyleCombo.API
```
Expected: a new file `api/FreestyleCombo.Infrastructure/Data/Migrations/<timestamp>_MakePreferenceFieldsOptional.cs` containing four `AlterColumn<int>(..., nullable: true, oldClrType: typeof(int), oldType: "integer")` calls (one each for `MaxDifficulty`, `ComboLength`, `NoTouchPercentage`, `MaxConsecutiveNoTouch`) in `Up()`, and the reverse (`nullable: false`) in `Down()`. Read the generated file and confirm exactly these four columns changed — no other column should appear in the diff.

- [ ] **Step 3: Apply the migration locally**

Run: `docker-compose up -d` (if not already running), then:
```bash
cd api
dotnet ef database update --project FreestyleCombo.Infrastructure --startup-project FreestyleCombo.API
```
Expected: `Applying migration '..._MakePreferenceFieldsOptional'.` then `Done.`

- [ ] **Step 4: Build to confirm the entity change alone doesn't break anything yet**

Run: `cd api && dotnet build`
Expected: build errors in `CreatePreferenceCommand.cs`, `UpdatePreferencesCommand.cs`, `PreferenceRequest` (in `PreferencesController.cs`), and test files that assign `UserPreference.MaxDifficulty`/`ComboLength`/`NoTouchPercentage`/`MaxConsecutiveNoTouch` — this is expected at this point; the next tasks fix each one. Confirm the errors are ONLY about these four fields (no unrelated breakage).

- [ ] **Step 5: Commit**

```bash
git add api/FreestyleCombo.Core/Entities/UserPreference.cs api/FreestyleCombo.Infrastructure/Data/Migrations/
git commit -m "$(cat <<'EOF'
Make four UserPreference fields nullable, flip IncludeKnee default

ComboLength/MaxDifficulty/NoTouchPercentage/MaxConsecutiveNoTouch become
optional — a saved preference can now omit them entirely, matching the
existing MaxHighRevolutionTricks/AllowedRevolutions pattern. IncludeKnee's
default flips from on to off. This alone doesn't compile yet — the next
tasks update every consumer.
EOF
)"
```

---

### Task 2: `CreatePreference` — nullable types + validator guards

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Preferences/CreatePreference/CreatePreferenceCommand.cs`
- Modify: `api/FreestyleCombo.API/Features/Preferences/CreatePreference/CreatePreferenceValidator.cs`
- Modify: `api/FreestyleCombo.API/Controllers/PreferencesController.cs`

- [ ] **Step 1: Update the command record**

Find (`CreatePreferenceCommand.cs`):
```csharp
public record CreatePreferenceCommand(
    Guid UserId,
    string Name,
    int MaxDifficulty,
    int ComboLength,
    int StrongFootPercentage,
    int NoTouchPercentage,
    int MaxConsecutiveNoTouch,
    bool IncludeCrossOver,
    bool IncludeKnee,
    List<decimal> AllowedRevolutions,
    int? MaxHighRevolutionTricks,
    List<Guid> AllowedTrickIds
) : IRequest<PreferenceDto>;
```

Replace with:
```csharp
public record CreatePreferenceCommand(
    Guid UserId,
    string Name,
    int? MaxDifficulty,
    int? ComboLength,
    int StrongFootPercentage,
    int? NoTouchPercentage,
    int? MaxConsecutiveNoTouch,
    bool IncludeCrossOver,
    bool IncludeKnee,
    List<decimal> AllowedRevolutions,
    int? MaxHighRevolutionTricks,
    List<Guid> AllowedTrickIds
) : IRequest<PreferenceDto>;
```

- [ ] **Step 2: Add `.When(HasValue)` guards to the validator**

Find (`CreatePreferenceValidator.cs`):
```csharp
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.MaxDifficulty).InclusiveBetween(1, 10);
        RuleFor(x => x.ComboLength).InclusiveBetween(1, 100);
        RuleFor(x => x.StrongFootPercentage).InclusiveBetween(0, 100);
        RuleFor(x => x.NoTouchPercentage).InclusiveBetween(0, 100);
        RuleFor(x => x.MaxConsecutiveNoTouch).InclusiveBetween(0, 30);
        RuleForEach(x => x.AllowedRevolutions).InclusiveBetween(0.5m, 4m);
        RuleFor(x => x.MaxHighRevolutionTricks).InclusiveBetween(1, 15).When(x => x.MaxHighRevolutionTricks.HasValue);
```

Replace with:
```csharp
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.MaxDifficulty).InclusiveBetween(1, 10).When(x => x.MaxDifficulty.HasValue);
        RuleFor(x => x.ComboLength).InclusiveBetween(1, 100).When(x => x.ComboLength.HasValue);
        RuleFor(x => x.StrongFootPercentage).InclusiveBetween(0, 100);
        RuleFor(x => x.NoTouchPercentage).InclusiveBetween(0, 100).When(x => x.NoTouchPercentage.HasValue);
        RuleFor(x => x.MaxConsecutiveNoTouch).InclusiveBetween(0, 30).When(x => x.MaxConsecutiveNoTouch.HasValue);
        RuleForEach(x => x.AllowedRevolutions).InclusiveBetween(0.5m, 4m);
        RuleFor(x => x.MaxHighRevolutionTricks).InclusiveBetween(1, 15).When(x => x.MaxHighRevolutionTricks.HasValue);
```

- [ ] **Step 3: Update `PreferenceRequest` and both places it's passed to a command**

Find (`PreferencesController.cs`, the `PreferenceRequest` class at the bottom of the file):
```csharp
public class PreferenceRequest
{
    public string? Name { get; set; }
    public int MaxDifficulty { get; set; } = 10;
    public int ComboLength { get; set; } = 6;
    public int StrongFootPercentage { get; set; } = 60;
    public int NoTouchPercentage { get; set; } = 30;
    public int MaxConsecutiveNoTouch { get; set; } = 2;
    public bool IncludeCrossOver { get; set; } = true;
    public bool IncludeKnee { get; set; } = true;
    public List<decimal> AllowedRevolutions { get; set; } = [];
    public int? MaxHighRevolutionTricks { get; set; }
    public List<Guid> AllowedTrickIds { get; set; } = [];
}
```

Replace with:
```csharp
public class PreferenceRequest
{
    public string? Name { get; set; }
    public int? MaxDifficulty { get; set; }
    public int? ComboLength { get; set; }
    public int StrongFootPercentage { get; set; } = 60;
    public int? NoTouchPercentage { get; set; }
    public int? MaxConsecutiveNoTouch { get; set; }
    public bool IncludeCrossOver { get; set; } = true;
    public bool IncludeKnee { get; set; } = false;
    public List<decimal> AllowedRevolutions { get; set; } = [];
    public int? MaxHighRevolutionTricks { get; set; }
    public List<Guid> AllowedTrickIds { get; set; } = [];
}
```

No changes needed to the `Create`/`Update` action bodies themselves — they already pass `request.MaxDifficulty` etc. straight through positionally, which continues to compile once both sides are `int?`.

- [ ] **Step 4: Build**

Run: `cd api && dotnet build`
Expected: `CreatePreferenceHandler.cs` compiles unchanged (straight `pref.MaxDifficulty = request.MaxDifficulty` assignment, both `int?` now). Remaining errors should now only be in `UpdatePreferences*`, `GetPreferencesQuery.cs`, and test files — confirm `CreatePreference*` and `PreferencesController.cs` no longer appear in the error list.

- [ ] **Step 5: Commit**

```bash
git add api/FreestyleCombo.API/Features/Preferences/CreatePreference/ api/FreestyleCombo.API/Controllers/PreferencesController.cs
git commit -m "$(cat <<'EOF'
CreatePreference: nullable optional fields + validator guards

EOF
)"
```

---

### Task 3: `UpdatePreferences` — nullable types + validator guards

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Preferences/UpdatePreferences/UpdatePreferencesCommand.cs`
- Modify: `api/FreestyleCombo.API/Features/Preferences/UpdatePreferences/UpdatePreferencesValidator.cs`

- [ ] **Step 1: Update the command record**

Find (`UpdatePreferencesCommand.cs`):
```csharp
public record UpdatePreferencesCommand(
    Guid PreferenceId,
    Guid CallerId,
    string Name,
    int MaxDifficulty,
    int ComboLength,
    int StrongFootPercentage,
    int NoTouchPercentage,
    int MaxConsecutiveNoTouch,
    bool IncludeCrossOver,
    bool IncludeKnee,
    List<decimal> AllowedRevolutions,
    int? MaxHighRevolutionTricks,
    List<Guid> AllowedTrickIds
) : IRequest<PreferenceDto>;
```

Replace with:
```csharp
public record UpdatePreferencesCommand(
    Guid PreferenceId,
    Guid CallerId,
    string Name,
    int? MaxDifficulty,
    int? ComboLength,
    int StrongFootPercentage,
    int? NoTouchPercentage,
    int? MaxConsecutiveNoTouch,
    bool IncludeCrossOver,
    bool IncludeKnee,
    List<decimal> AllowedRevolutions,
    int? MaxHighRevolutionTricks,
    List<Guid> AllowedTrickIds
) : IRequest<PreferenceDto>;
```

- [ ] **Step 2: Add `.When(HasValue)` guards**

Find (`UpdatePreferencesValidator.cs`):
```csharp
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.MaxDifficulty).InclusiveBetween(1, 10);
        RuleFor(x => x.ComboLength).InclusiveBetween(1, 100);
        RuleFor(x => x.StrongFootPercentage).InclusiveBetween(0, 100);
        RuleFor(x => x.NoTouchPercentage).InclusiveBetween(0, 100);
        RuleFor(x => x.MaxConsecutiveNoTouch).InclusiveBetween(0, 30);
        RuleForEach(x => x.AllowedRevolutions).InclusiveBetween(0.5m, 4m);
        RuleFor(x => x.MaxHighRevolutionTricks).InclusiveBetween(1, 15).When(x => x.MaxHighRevolutionTricks.HasValue);
```

Replace with:
```csharp
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.MaxDifficulty).InclusiveBetween(1, 10).When(x => x.MaxDifficulty.HasValue);
        RuleFor(x => x.ComboLength).InclusiveBetween(1, 100).When(x => x.ComboLength.HasValue);
        RuleFor(x => x.StrongFootPercentage).InclusiveBetween(0, 100);
        RuleFor(x => x.NoTouchPercentage).InclusiveBetween(0, 100).When(x => x.NoTouchPercentage.HasValue);
        RuleFor(x => x.MaxConsecutiveNoTouch).InclusiveBetween(0, 30).When(x => x.MaxConsecutiveNoTouch.HasValue);
        RuleForEach(x => x.AllowedRevolutions).InclusiveBetween(0.5m, 4m);
        RuleFor(x => x.MaxHighRevolutionTricks).InclusiveBetween(1, 15).When(x => x.MaxHighRevolutionTricks.HasValue);
```

- [ ] **Step 3: Build**

Run: `cd api && dotnet build`
Expected: `UpdatePreferencesHandler.cs` compiles unchanged (same straight-assignment pattern). Remaining errors should now only be in `GetPreferencesQuery.cs` and test files.

- [ ] **Step 4: Commit**

```bash
git add api/FreestyleCombo.API/Features/Preferences/UpdatePreferences/
git commit -m "$(cat <<'EOF'
UpdatePreferences: nullable optional fields + validator guards

EOF
)"
```

---

### Task 4: `PreferenceDto` — nullable types

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Preferences/GetPreferences/GetPreferencesQuery.cs`

- [ ] **Step 1: Update the DTO**

Find:
```csharp
public class PreferenceDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int MaxDifficulty { get; set; }
    public int ComboLength { get; set; }
    public int StrongFootPercentage { get; set; }
    public int NoTouchPercentage { get; set; }
    public int MaxConsecutiveNoTouch { get; set; }
    public bool IncludeCrossOver { get; set; }
    public bool IncludeKnee { get; set; }
    public List<decimal> AllowedRevolutions { get; set; } = [];
    public int? MaxHighRevolutionTricks { get; set; }
    public List<Guid> AllowedTrickIds { get; set; } = [];
}
```

Replace with:
```csharp
public class PreferenceDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int? MaxDifficulty { get; set; }
    public int? ComboLength { get; set; }
    public int StrongFootPercentage { get; set; }
    public int? NoTouchPercentage { get; set; }
    public int? MaxConsecutiveNoTouch { get; set; }
    public bool IncludeCrossOver { get; set; }
    public bool IncludeKnee { get; set; }
    public List<decimal> AllowedRevolutions { get; set; } = [];
    public int? MaxHighRevolutionTricks { get; set; }
    public List<Guid> AllowedTrickIds { get; set; } = [];
}
```

- [ ] **Step 2: Build**

Run: `cd api && dotnet build`
Expected: `GetPreferencesHandler.cs` compiles unchanged (straight assignment). Remaining errors should now be ONLY in test files (`PreferenceHandlerTests.cs` if it constructs `UserPreference`/commands with anything besides plain int literals — per the audit, it doesn't, so this should already build clean; if not, read the actual compiler error and fix the specific line).

- [ ] **Step 3: Commit**

```bash
git add api/FreestyleCombo.API/Features/Preferences/GetPreferences/GetPreferencesQuery.cs
git commit -m "$(cat <<'EOF'
GetPreferences: PreferenceDto nullable optional fields

EOF
)"
```

---

### Task 5: `IncludeKnee` default flip in combo generation

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Combos/GenerateCombo/GenerateComboHandler.cs`
- Modify: `api/FreestyleCombo.API/Features/Combos/PreviewCombo/PreviewComboHandler.cs`

- [ ] **Step 1: Flip the fallback in `GenerateComboHandler.cs`**

Find:
```csharp
        var includeKnee = request.Overrides?.IncludeKnee ?? savedPref?.IncludeKnee ?? true;
```

Replace with:
```csharp
        var includeKnee = request.Overrides?.IncludeKnee ?? savedPref?.IncludeKnee ?? false;
```

- [ ] **Step 2: Same fix in `PreviewComboHandler.cs`**

Find:
```csharp
        var includeKnee = request.Overrides?.IncludeKnee ?? savedPref?.IncludeKnee ?? true;
```

Replace with:
```csharp
        var includeKnee = request.Overrides?.IncludeKnee ?? savedPref?.IncludeKnee ?? false;
```

- [ ] **Step 3: Build**

Run: `cd api && dotnet build`
Expected: `Build succeeded.` with 0 errors (only pre-existing warnings, if any — the same ones seen before this feature).

- [ ] **Step 4: Commit**

```bash
git add api/FreestyleCombo.API/Features/Combos/GenerateCombo/GenerateComboHandler.cs api/FreestyleCombo.API/Features/Combos/PreviewCombo/PreviewComboHandler.cs
git commit -m "$(cat <<'EOF'
Flip IncludeKnee's hardcoded fallback default to false

Only affects the rare case where neither an override nor a saved
preference supplies a value — every real request already sends a
concrete boolean today.
EOF
)"
```

---

### Task 6: Backend tests for nullable fields

**Files:**
- Modify: `api/FreestyleCombo.Tests/Features/PreferenceHandlerTests.cs`
- Modify: `api/FreestyleCombo.Tests/Features/GenerateComboHandlerTests.cs`

- [ ] **Step 1: Write the failing tests**

Add to `PreferenceHandlerTests.cs`, right after the `CreatePreference_ReturnsPreferenceDtoWithCorrectFields` test:
```csharp
    [Fact]
    public async Task CreatePreference_WithNullOptionalFields_SavesNulls()
    {
        _repo.Setup(r => r.AddAsync(It.IsAny<UserPreference>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        var command = new CreatePreferenceCommand(
            _userId, "No Limits", null, null, 50, null, null, true, false, [], null, []);

        var result = await new CreatePreferenceHandler(_repo.Object)
            .Handle(command, CancellationToken.None);

        result.MaxDifficulty.Should().BeNull();
        result.ComboLength.Should().BeNull();
        result.NoTouchPercentage.Should().BeNull();
        result.MaxConsecutiveNoTouch.Should().BeNull();
        result.StrongFootPercentage.Should().Be(50);
    }
```

Add to the same file, right after `UpdatePreferences_Owner_UpdatesAndReturnsDto`:
```csharp
    [Fact]
    public async Task UpdatePreferences_WithNullOptionalFields_SavesNulls()
    {
        var pref = StoredPref();
        _repo.Setup(r => r.GetByIdAsync(_prefId, It.IsAny<CancellationToken>())).ReturnsAsync(pref);
        _repo.Setup(r => r.UpdateAsync(pref, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        var command = new UpdatePreferencesCommand(
            _prefId, _userId, "Updated", null, null, 50, null, null, true, false, [], null, []);

        var result = await new UpdatePreferencesHandler(_repo.Object)
            .Handle(command, CancellationToken.None);

        result.MaxDifficulty.Should().BeNull();
        result.ComboLength.Should().BeNull();
        result.NoTouchPercentage.Should().BeNull();
        result.MaxConsecutiveNoTouch.Should().BeNull();
    }
```

Add to `GenerateComboHandlerTests.cs`, right after `Handle_UsesPreference_WhenPreferenceIdProvided` (before the closing `}` of the class):
```csharp

    [Fact]
    public async Task Handle_UsesHardcodedDefault_WhenSavedPreferenceFieldIsNull()
    {
        var tricks = TrickFaker.DefaultPool();
        _trickRepo.Setup(r => r.GetAllAsync(It.IsAny<bool?>(), It.IsAny<bool?>(), It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(tricks);

        var prefId = Guid.NewGuid();
        var savedPref = new UserPreference
        {
            Id = prefId,
            UserId = _userId,
            Name = "No Limits",
            ComboLength = null,
            MaxDifficulty = null
        };
        _prefRepo.Setup(r => r.GetByIdAsync(prefId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(savedPref);

        var handler = CreateHandler();
        var command = new GenerateComboCommand(prefId, null);

        var result = await handler.Handle(command, CancellationToken.None);

        // ComboLength null -> falls back to the hardcoded default of 6.
        result.TrickCount.Should().Be(6);
    }
```

- [ ] **Step 2: Run to verify they pass**

Run: `cd api && dotnet test --filter "FullyQualifiedName~CreatePreference_WithNullOptionalFields|FullyQualifiedName~UpdatePreferences_WithNullOptionalFields|FullyQualifiedName~Handle_UsesHardcodedDefault_WhenSavedPreferenceFieldIsNull"`
Expected: `Passed!  - Failed: 0, Passed: 3, Skipped: 0, Total: 3`

- [ ] **Step 3: Run the full suite**

Run: `cd api && dotnet test`
Expected: `Passed!  - Failed: 0, Passed: 233, Skipped: 0, Total: 233` (230 existing + 3 new).

- [ ] **Step 4: Commit**

```bash
git add api/FreestyleCombo.Tests/Features/PreferenceHandlerTests.cs api/FreestyleCombo.Tests/Features/GenerateComboHandlerTests.cs
git commit -m "$(cat <<'EOF'
Add tests for nullable preference fields

Covers Create/UpdatePreferencesHandler persisting explicit nulls, and
GenerateComboHandler resolving a null saved-preference field to its
existing hardcoded default (the resolution logic itself is unchanged —
this just proves it still works once the property is nullable).
EOF
)"
```

---

### Task 7: Web type updates

**Files:**
- Modify: `web/src/lib/api/preferences.ts`

- [ ] **Step 1: Update the interface**

Find:
```ts
export interface UserPreference {
  id: string
  userId?: string
  name: string
  comboLength: number
  maxDifficulty: number
  strongFootPercentage: number
  noTouchPercentage: number
  maxConsecutiveNoTouch: number
  includeCrossOver: boolean
  includeKnee: boolean
  allowedRevolutions: number[]
  maxHighRevolutionTricks: number | null
  allowedTrickIds: string[]
}
```

Replace with:
```ts
export interface UserPreference {
  id: string
  userId?: string
  name: string
  comboLength: number | null
  maxDifficulty: number | null
  strongFootPercentage: number
  noTouchPercentage: number | null
  maxConsecutiveNoTouch: number | null
  includeCrossOver: boolean
  includeKnee: boolean
  allowedRevolutions: number[]
  maxHighRevolutionTricks: number | null
  allowedTrickIds: string[]
}
```

- [ ] **Step 2: Type-check**

Run: `cd web && npx tsc -b --noEmit`
Expected: errors in `PreferencesPage.tsx` (lines binding `form.comboLength`/`maxDifficulty`/`noTouchPercentage`/`maxConsecutiveNoTouch` directly to `<Input value>`) and `CreateComboPage.tsx` (same, via `selectedPref.X`) — expected at this point, fixed in Tasks 9-10.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/api/preferences.ts
git commit -m "$(cat <<'EOF'
Web: UserPreference's optional fields become number | null

EOF
)"
```

---

### Task 8: Web `OptionalField` component

**Files:**
- Create: `web/src/components/ui/optional-field.tsx`

- [ ] **Step 1: Write the component**

```tsx
import { Label } from '@/components/ui/label'

interface OptionalFieldProps {
  label: string
  enabled: boolean
  onToggle: (enabled: boolean) => void
  disabled?: boolean
  className?: string
  children: React.ReactNode
}

/**
 * Wraps a field with an enable/disable checkbox. When disabled, the field
 * is hidden entirely and its value is meant to be sent as null/empty
 * rather than a specific number — the caller decides what "off" means for
 * its own field, this component only controls visibility.
 */
export function OptionalField({ label, enabled, onToggle, disabled = false, className, children }: OptionalFieldProps) {
  return (
    <div className={className ?? 'space-y-1'}>
      <div className="flex items-center justify-between">
        <Label className={disabled ? 'text-gray-400' : ''}>{label}</Label>
        <input
          type="checkbox"
          checked={enabled}
          disabled={disabled}
          onChange={(e) => onToggle(e.target.checked)}
          className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
        />
      </div>
      {enabled && <div className="mt-1">{children}</div>}
    </div>
  )
}
```

- [ ] **Step 2: Type-check**

Run: `cd web && npx tsc -b --noEmit`
Expected: no new errors from this file (the pre-existing errors from Task 7 remain until Tasks 9-10 land).

- [ ] **Step 3: Commit**

```bash
git add web/src/components/ui/optional-field.tsx
git commit -m "$(cat <<'EOF'
Add OptionalField toggle wrapper (web)

Standalone, not wired into any page yet.
EOF
)"
```

---

### Task 9: Wire into web `PreferencesPage.tsx`

**Files:**
- Modify: `web/src/features/preferences/PreferencesPage.tsx`

- [ ] **Step 1: Add the import**

Find:
```tsx
import { RevRangeSlider } from '@/components/ui/rev-range-slider'
import { decodeRevolutionRange, encodeRevolutionRange } from '@/lib/revolutionRange'
```

Replace with:
```tsx
import { RevRangeSlider } from '@/components/ui/rev-range-slider'
import { OptionalField } from '@/components/ui/optional-field'
import { decodeRevolutionRange, encodeRevolutionRange } from '@/lib/revolutionRange'
```

- [ ] **Step 2: Flip `DEFAULTS.includeKnee`**

Find:
```ts
const DEFAULTS: PreferencePayload = {
  name: '',
  comboLength: 6,
  maxDifficulty: 10,
  strongFootPercentage: 60,
  noTouchPercentage: 30,
  maxConsecutiveNoTouch: 2,
  includeCrossOver: true,
  includeKnee: true,
  allowedRevolutions: [],
  maxHighRevolutionTricks: 1,
  allowedTrickIds: [],
}
```

Replace with:
```ts
const DEFAULTS: PreferencePayload = {
  name: '',
  comboLength: 6,
  maxDifficulty: 10,
  strongFootPercentage: 60,
  noTouchPercentage: 30,
  maxConsecutiveNoTouch: 2,
  includeCrossOver: true,
  includeKnee: false,
  allowedRevolutions: [],
  maxHighRevolutionTricks: 1,
  allowedTrickIds: [],
}
```

- [ ] **Step 3: Replace the entire `PreferenceForm` function**

Find the whole function, from `function PreferenceForm({` through its closing `}` (right before `function PreferenceCard({`):
```tsx
function PreferenceForm({
  initial,
  onSave,
  onCancel,
  isPending,
  error,
}: {
  initial: PreferencePayload
  onSave: (p: PreferencePayload) => void
  onCancel: () => void
  isPending: boolean
  error: string | null
}) {
  const [form, setForm] = useState<PreferencePayload>(initial)
  const { t } = useTranslation()

  function update<K extends keyof PreferencePayload>(key: K, value: PreferencePayload[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  const revRange = decodeRevolutionRange(form.allowedRevolutions)

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        onSave(form)
      }}
      className="space-y-4"
    >
      <div className="space-y-1">
        <Label>{t('preferences.fieldName')}</Label>
        <Input
          required
          maxLength={100}
          placeholder={t('preferences.fieldNamePlaceholder')}
          value={form.name}
          onChange={(e) => update('name', e.target.value)}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
        <div className="space-y-1">
          <Label>{t('preferences.comboLength')}</Label>
          <Input type="number" min={1} max={100} value={form.comboLength} onChange={(e) => update('comboLength', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>{t('preferences.maxDifficulty')}</Label>
          <Input type="number" min={1} max={10} value={form.maxDifficulty} onChange={(e) => update('maxDifficulty', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>{t('preferences.strongFootPct')}</Label>
          <Input type="number" min={0} max={100} value={form.strongFootPercentage} onChange={(e) => update('strongFootPercentage', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>{t('preferences.noTouchPct')}</Label>
          <Input type="number" min={0} max={100} value={form.noTouchPercentage} onChange={(e) => update('noTouchPercentage', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>{t('preferences.maxConsecutiveNT')}</Label>
          <Input type="number" min={0} max={30} value={form.maxConsecutiveNoTouch} onChange={(e) => update('maxConsecutiveNoTouch', Number(e.target.value))} />
        </div>
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
            min={revRange.min}
            max={revRange.max}
            onChange={(min, max) => update('allowedRevolutions', encodeRevolutionRange(min, max))}
            allLabel={t('common.revRangeAll')}
            formatRangeLabel={(min, max) => t('common.revRangeValue', { min: min.toFixed(1), max: max.toFixed(1) })}
            minAriaLabel={t('common.revRangeMinAria')}
            maxAriaLabel={t('common.revRangeMaxAria')}
          />
        </div>
      </div>

      <div className="flex flex-wrap gap-4">
        <div className="flex items-center gap-2">
          <input id="pf-crossover" type="checkbox" checked={form.includeCrossOver} onChange={(e) => update('includeCrossOver', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
          <Label htmlFor="pf-crossover">{t('preferences.includeCrossover')}</Label>
        </div>
        <div className="flex items-center gap-2">
          <input id="pf-knee" type="checkbox" checked={form.includeKnee} onChange={(e) => update('includeKnee', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
          <Label htmlFor="pf-knee">{t('preferences.includeKnee')}</Label>
        </div>
      </div>

      <TrickPicker selectedIds={form.allowedTrickIds} onChange={(ids) => update('allowedTrickIds', ids)} />

      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="flex gap-2">
        <Button type="submit" disabled={isPending}>
          {isPending ? t('common.saving') : t('common.save')}
        </Button>
        <Button type="button" variant="ghost" onClick={onCancel}>
          {t('common.cancel')}
        </Button>
      </div>
    </form>
  )
}
```

Replace with:
```tsx
function PreferenceForm({
  initial,
  onSave,
  onCancel,
  isPending,
  error,
}: {
  initial: PreferencePayload
  onSave: (p: PreferencePayload) => void
  onCancel: () => void
  isPending: boolean
  error: string | null
}) {
  const [form, setForm] = useState<PreferencePayload>(initial)
  const [revEnabled, setRevEnabled] = useState(initial.allowedRevolutions.length > 0)
  const { t } = useTranslation()

  function update<K extends keyof PreferencePayload>(key: K, value: PreferencePayload[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  const revRange = decodeRevolutionRange(form.allowedRevolutions)

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        onSave({ ...form, allowedRevolutions: revEnabled ? form.allowedRevolutions : [] })
      }}
      className="space-y-4"
    >
      <div className="space-y-1">
        <Label>{t('preferences.fieldName')}</Label>
        <Input
          required
          maxLength={100}
          placeholder={t('preferences.fieldNamePlaceholder')}
          value={form.name}
          onChange={(e) => update('name', e.target.value)}
        />
      </div>

      <TrickPicker selectedIds={form.allowedTrickIds} onChange={(ids) => update('allowedTrickIds', ids)} />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
        <OptionalField
          label={t('preferences.comboLength')}
          enabled={form.comboLength !== null}
          onToggle={(enabled) => update('comboLength', enabled ? 6 : null)}
        >
          <Input type="number" min={1} max={100} value={form.comboLength ?? 6} onChange={(e) => update('comboLength', Number(e.target.value))} />
        </OptionalField>

        <OptionalField
          label={t('preferences.revRange')}
          enabled={revEnabled}
          onToggle={setRevEnabled}
          className="space-y-1 sm:col-span-2 md:col-span-3"
        >
          <RevRangeSlider
            min={revRange.min}
            max={revRange.max}
            onChange={(min, max) => update('allowedRevolutions', encodeRevolutionRange(min, max))}
            allLabel={t('common.revRangeAll')}
            formatRangeLabel={(min, max) => t('common.revRangeValue', { min: min.toFixed(1), max: max.toFixed(1) })}
            minAriaLabel={t('common.revRangeMinAria')}
            maxAriaLabel={t('common.revRangeMaxAria')}
          />
        </OptionalField>

        <div className="space-y-1">
          <Label>{t('preferences.strongFootPct')}</Label>
          <Input type="number" min={0} max={100} value={form.strongFootPercentage} onChange={(e) => update('strongFootPercentage', Number(e.target.value))} />
        </div>

        <OptionalField
          label={t('preferences.noTouchPct')}
          enabled={form.noTouchPercentage !== null}
          onToggle={(enabled) => update('noTouchPercentage', enabled ? 30 : null)}
        >
          <Input type="number" min={0} max={100} value={form.noTouchPercentage ?? 30} onChange={(e) => update('noTouchPercentage', Number(e.target.value))} />
        </OptionalField>

        <OptionalField
          label={t('preferences.maxConsecutiveNT')}
          enabled={form.maxConsecutiveNoTouch !== null}
          onToggle={(enabled) => update('maxConsecutiveNoTouch', enabled ? 2 : null)}
        >
          <Input type="number" min={0} max={30} value={form.maxConsecutiveNoTouch ?? 2} onChange={(e) => update('maxConsecutiveNoTouch', Number(e.target.value))} />
        </OptionalField>

        <OptionalField
          label={t('preferences.maxHighRevTricks')}
          enabled={form.maxHighRevolutionTricks !== null}
          onToggle={(enabled) => update('maxHighRevolutionTricks', enabled ? 1 : null)}
        >
          <Input
            type="number"
            min={1}
            max={15}
            value={form.maxHighRevolutionTricks ?? 1}
            onChange={(e) => update('maxHighRevolutionTricks', Math.min(15, Math.max(1, Number(e.target.value))))}
          />
        </OptionalField>

        <OptionalField
          label={t('preferences.maxDifficulty')}
          enabled={form.maxDifficulty !== null}
          onToggle={(enabled) => update('maxDifficulty', enabled ? 10 : null)}
        >
          <Input type="number" min={1} max={10} value={form.maxDifficulty ?? 10} onChange={(e) => update('maxDifficulty', Number(e.target.value))} />
        </OptionalField>
      </div>

      <div className="flex flex-wrap gap-4">
        <div className="flex items-center gap-2">
          <input id="pf-crossover" type="checkbox" checked={form.includeCrossOver} onChange={(e) => update('includeCrossOver', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
          <Label htmlFor="pf-crossover">{t('preferences.includeCrossover')}</Label>
        </div>
        <div className="flex items-center gap-2">
          <input id="pf-knee" type="checkbox" checked={form.includeKnee} onChange={(e) => update('includeKnee', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
          <Label htmlFor="pf-knee">{t('preferences.includeKnee')}</Label>
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="flex gap-2">
        <Button type="submit" disabled={isPending}>
          {isPending ? t('common.saving') : t('common.save')}
        </Button>
        <Button type="button" variant="ghost" onClick={onCancel}>
          {t('common.cancel')}
        </Button>
      </div>
    </form>
  )
}
```

Note: `form.comboLength`/`maxDifficulty`/`noTouchPercentage`/`maxConsecutiveNoTouch`/`maxHighRevolutionTricks` still hold a live number at all times while their `OptionalField` is showing its slider (the `?? <default>` in each `value={...}` only matters for the render right after enabling, before the user drags anything) — toggling off always resets to `null`, toggling back on always resets to the field's hardcoded default (no "remember the last custom value" — a deliberate simplification, see the design spec's "Toggle semantics" section).

- [ ] **Step 4: Fix the `PreferenceCard` stats line for null-safe display**

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
    length: pref.comboLength ?? '—',
    maxDiff: pref.maxDifficulty ?? '—',
    sf: pref.strongFootPercentage,
    nt: pref.noTouchPercentage ?? '—',
  })
```

- [ ] **Step 5: Fix the flags caption to conditionally show `maxConsecutiveNoTouch`**

Find:
```tsx
            {pref.includeCrossOver ? 'CO ✓' : 'CO ✗'} · {pref.includeKnee ? `${t('preferences.kneeLabel')} ✓` : `${t('preferences.kneeLabel')} ✗`} · {t('preferences.maxConsecLabel')} {pref.maxConsecutiveNoTouch}
            {pref.maxHighRevolutionTricks != null && <> · {t('preferences.maxHighRevLabel')} {pref.maxHighRevolutionTricks}</>}
```

Replace with:
```tsx
            {pref.includeCrossOver ? 'CO ✓' : 'CO ✗'} · {pref.includeKnee ? `${t('preferences.kneeLabel')} ✓` : `${t('preferences.kneeLabel')} ✗`}
            {pref.maxConsecutiveNoTouch != null && <> · {t('preferences.maxConsecLabel')} {pref.maxConsecutiveNoTouch}</>}
            {pref.maxHighRevolutionTricks != null && <> · {t('preferences.maxHighRevLabel')} {pref.maxHighRevolutionTricks}</>}
```

- [ ] **Step 6: Type-check, lint, build**

Run: `cd web && npm run build`
Expected: build succeeds, no TypeScript errors.

- [ ] **Step 7: Commit**

```bash
git add web/src/features/preferences/PreferencesPage.tsx
git commit -m "$(cat <<'EOF'
Preference form: optional fields, reorder, knee default off (web)

New order: Name, Allowed tricks, Combo length, Revolutions, Strong foot,
No-touch, Max consecutive no-touch, Max 3+ rev tricks, Max difficulty,
Include cross-overs, Include knee tricks. Six fields (Combo length,
Revolutions, No-touch, Max consecutive no-touch, Max 3+ rev tricks, Max
difficulty) are now individually toggleable via OptionalField — off sends
null (or [] for Revolutions), not a specific number.
EOF
)"
```

---

### Task 10: Wire into web `CreateComboPage.tsx`

**Files:**
- Modify: `web/src/features/combos/CreateComboPage.tsx`

- [ ] **Step 1: Add the import**

Find:
```tsx
import { Badge } from '@/components/ui/badge'
import { RevRangeSlider } from '@/components/ui/rev-range-slider'
```

Replace with:
```tsx
import { Badge } from '@/components/ui/badge'
import { RevRangeSlider } from '@/components/ui/rev-range-slider'
import { OptionalField } from '@/components/ui/optional-field'
```

- [ ] **Step 2: Flip `GENERATE_DEFAULTS.includeKnee`**

Find:
```ts
const GENERATE_DEFAULTS: GenerateComboOverrides = {
  comboLength: 5,
  maxDifficulty: 10,
  strongFootPercentage: 50,
  noTouchPercentage: 30,
  maxConsecutiveNoTouch: 2,
  includeCrossOver: true,
  includeKnee: true,
  maxHighRevolutionTricks: 1,
}
```

Replace with:
```ts
const GENERATE_DEFAULTS: GenerateComboOverrides = {
  comboLength: 5,
  maxDifficulty: 10,
  strongFootPercentage: 50,
  noTouchPercentage: 30,
  maxConsecutiveNoTouch: 2,
  includeCrossOver: true,
  includeKnee: false,
  maxHighRevolutionTricks: 1,
}
```

- [ ] **Step 3: Replace the fields grid**

Find (the whole block from the opening `<div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">` for the fields, through its matching closing `</div>` right before `{selectedPref && (`):
```tsx
            {/* Fields — editable when Custom, read-only when preference selected */}
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              <div className="space-y-1">
                <Label>{t('create.comboLength')}</Label>
                <Input
                  type="number" min={1} max={100}
                  value={selectedPref ? selectedPref.comboLength : overrides.comboLength}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('comboLength', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('create.maxDifficulty')}</Label>
                <Input
                  type="number" min={1} max={10}
                  value={selectedPref ? selectedPref.maxDifficulty : overrides.maxDifficulty}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxDifficulty', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('create.strongFootPct')}</Label>
                <Input
                  type="number" min={0} max={100}
                  value={selectedPref ? selectedPref.strongFootPercentage : overrides.strongFootPercentage}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('strongFootPercentage', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('create.noTouchPct')}</Label>
                <Input
                  type="number" min={0} max={100}
                  value={selectedPref ? selectedPref.noTouchPercentage : overrides.noTouchPercentage}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('noTouchPercentage', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('create.maxConsecutiveNT')}</Label>
                <Input
                  type="number" min={0} max={30}
                  value={selectedPref ? selectedPref.maxConsecutiveNoTouch : overrides.maxConsecutiveNoTouch}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxConsecutiveNoTouch', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
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
                  allLabel={t('common.revRangeAll')}
                  formatRangeLabel={(min, max) => t('common.revRangeValue', { min: min.toFixed(1), max: max.toFixed(1) })}
                  minAriaLabel={t('common.revRangeMinAria')}
                  maxAriaLabel={t('common.revRangeMaxAria')}
                />
              </div>
              <div className="flex flex-col gap-2 pt-1">
                <div className="flex items-center gap-2">
                  <input
                    id="gen-crossover" type="checkbox"
                    checked={selectedPref ? selectedPref.includeCrossOver : (overrides.includeCrossOver ?? true)}
                    disabled={!!selectedPref}
                    onChange={(e) => updateOverride('includeCrossOver', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
                  />
                  <Label htmlFor="gen-crossover" className={selectedPref ? 'text-gray-400' : ''}>{t('create.includeCrossover')}</Label>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    id="gen-knee" type="checkbox"
                    checked={selectedPref ? selectedPref.includeKnee : (overrides.includeKnee ?? true)}
                    disabled={!!selectedPref}
                    onChange={(e) => updateOverride('includeKnee', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
                  />
                  <Label htmlFor="gen-knee" className={selectedPref ? 'text-gray-400' : ''}>{t('create.includeKnee')}</Label>
                </div>
              </div>
            </div>
```

Replace with:
```tsx
            {/* Fields — editable when Custom, read-only/locked when preference selected */}
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              <OptionalField
                label={t('create.comboLength')}
                enabled={selectedPref ? selectedPref.comboLength !== null : overrides.comboLength !== undefined}
                onToggle={(enabled) => updateOverride('comboLength', enabled ? 5 : undefined)}
                disabled={!!selectedPref}
              >
                <Input
                  type="number" min={1} max={100}
                  value={(selectedPref ? selectedPref.comboLength : overrides.comboLength) ?? 5}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('comboLength', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </OptionalField>

              <OptionalField
                label={t('create.revRange')}
                enabled={selectedPref ? selectedPref.allowedRevolutions.length > 0 : overrides.allowedRevolutions !== undefined}
                onToggle={(enabled) => updateOverride('allowedRevolutions', enabled ? [] : undefined)}
                disabled={!!selectedPref}
                className="space-y-1 sm:col-span-2 md:col-span-3"
              >
                <RevRangeSlider
                  min={revRange.min}
                  max={revRange.max}
                  disabled={!!selectedPref}
                  onChange={(min, max) => updateOverride('allowedRevolutions', encodeRevolutionRange(min, max))}
                  allLabel={t('common.revRangeAll')}
                  formatRangeLabel={(min, max) => t('common.revRangeValue', { min: min.toFixed(1), max: max.toFixed(1) })}
                  minAriaLabel={t('common.revRangeMinAria')}
                  maxAriaLabel={t('common.revRangeMaxAria')}
                />
              </OptionalField>

              <div className="space-y-1">
                <Label>{t('create.strongFootPct')}</Label>
                <Input
                  type="number" min={0} max={100}
                  value={selectedPref ? selectedPref.strongFootPercentage : overrides.strongFootPercentage}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('strongFootPercentage', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>

              <OptionalField
                label={t('create.noTouchPct')}
                enabled={selectedPref ? selectedPref.noTouchPercentage !== null : overrides.noTouchPercentage !== undefined}
                onToggle={(enabled) => updateOverride('noTouchPercentage', enabled ? 30 : undefined)}
                disabled={!!selectedPref}
              >
                <Input
                  type="number" min={0} max={100}
                  value={(selectedPref ? selectedPref.noTouchPercentage : overrides.noTouchPercentage) ?? 30}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('noTouchPercentage', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </OptionalField>

              <OptionalField
                label={t('create.maxConsecutiveNT')}
                enabled={selectedPref ? selectedPref.maxConsecutiveNoTouch !== null : overrides.maxConsecutiveNoTouch !== undefined}
                onToggle={(enabled) => updateOverride('maxConsecutiveNoTouch', enabled ? 2 : undefined)}
                disabled={!!selectedPref}
              >
                <Input
                  type="number" min={0} max={30}
                  value={(selectedPref ? selectedPref.maxConsecutiveNoTouch : overrides.maxConsecutiveNoTouch) ?? 2}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxConsecutiveNoTouch', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </OptionalField>

              <OptionalField
                label={t('create.maxHighRevTricks')}
                enabled={selectedPref ? selectedPref.maxHighRevolutionTricks !== null : overrides.maxHighRevolutionTricks !== undefined}
                onToggle={(enabled) => updateOverride('maxHighRevolutionTricks', enabled ? 1 : undefined)}
                disabled={!!selectedPref}
              >
                <Input
                  type="number" min={1} max={15}
                  value={(selectedPref ? selectedPref.maxHighRevolutionTricks : overrides.maxHighRevolutionTricks) ?? 1}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxHighRevolutionTricks', Math.min(15, Math.max(1, Number(e.target.value))))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </OptionalField>

              <OptionalField
                label={t('create.maxDifficulty')}
                enabled={selectedPref ? selectedPref.maxDifficulty !== null : overrides.maxDifficulty !== undefined}
                onToggle={(enabled) => updateOverride('maxDifficulty', enabled ? 10 : undefined)}
                disabled={!!selectedPref}
              >
                <Input
                  type="number" min={1} max={10}
                  value={(selectedPref ? selectedPref.maxDifficulty : overrides.maxDifficulty) ?? 10}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxDifficulty', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </OptionalField>

              <div className="flex flex-col gap-2 pt-1">
                <div className="flex items-center gap-2">
                  <input
                    id="gen-crossover" type="checkbox"
                    checked={selectedPref ? selectedPref.includeCrossOver : (overrides.includeCrossOver ?? true)}
                    disabled={!!selectedPref}
                    onChange={(e) => updateOverride('includeCrossOver', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
                  />
                  <Label htmlFor="gen-crossover" className={selectedPref ? 'text-gray-400' : ''}>{t('create.includeCrossover')}</Label>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    id="gen-knee" type="checkbox"
                    checked={selectedPref ? selectedPref.includeKnee : (overrides.includeKnee ?? false)}
                    disabled={!!selectedPref}
                    onChange={(e) => updateOverride('includeKnee', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
                  />
                  <Label htmlFor="gen-knee" className={selectedPref ? 'text-gray-400' : ''}>{t('create.includeKnee')}</Label>
                </div>
              </div>
            </div>
```

- [ ] **Step 4: Build**

Run: `cd web && npm run build`
Expected: build succeeds, no TypeScript errors. (`updateOverride('field', undefined)` type-checks because every `GenerateComboOverrides` field is already optional — `undefined` is a valid value for `key?: T`.)

- [ ] **Step 5: Commit**

```bash
git add web/src/features/combos/CreateComboPage.tsx
git commit -m "$(cat <<'EOF'
Generate quick-overrides: optional fields, reorder, knee default off (web)

Same reorder and OptionalField toggles as the preference form. Unlike
there, "off" here is represented as undefined (the override key is
omitted from the request) rather than null/[] — GenerateComboOverrides'
fields are already optional, so this needed no type changes.
EOF
)"
```

---

### Task 11: Mobile model updates

**Files:**
- Modify: `mobile/lib/core/models/user_preference.dart`

- [ ] **Step 1: Make the fields nullable, fix the unsafe casts, flip `includeKnee`'s default**

Find:
```dart
class UserPreference {
  final String id;
  final String userId;
  final String name;
  final int comboLength;
  final int maxDifficulty;
  final int strongFootPercentage;
  final int noTouchPercentage;
  final int maxConsecutiveNoTouch;
  final bool includeCrossOver;
  final bool includeKnee;
  final List<double> allowedRevolutions;
  final int? maxHighRevolutionTricks;
  final List<String> allowedTrickIds;

  const UserPreference({
    required this.id,
    required this.userId,
    required this.name,
    required this.comboLength,
    required this.maxDifficulty,
    required this.strongFootPercentage,
    required this.noTouchPercentage,
    required this.maxConsecutiveNoTouch,
    required this.includeCrossOver,
    required this.includeKnee,
    required this.allowedRevolutions,
    this.maxHighRevolutionTricks,
    this.allowedTrickIds = const [],
  });

  factory UserPreference.fromJson(Map<String, dynamic> j) => UserPreference(
        id: (j['id'] as String?) ?? '',
        userId: (j['userId'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        comboLength: j['comboLength'] as int,
        maxDifficulty: j['maxDifficulty'] as int,
        strongFootPercentage: j['strongFootPercentage'] as int,
        noTouchPercentage: j['noTouchPercentage'] as int,
        maxConsecutiveNoTouch: j['maxConsecutiveNoTouch'] as int,
        includeCrossOver: j['includeCrossOver'] as bool,
        includeKnee: j['includeKnee'] as bool,
        allowedRevolutions:
          ((j['allowedRevolutions'] as List<dynamic>?) ??
              (j['allowedMotions'] as List<dynamic>?) ??
              [])
            .map((m) => (m as num).toDouble())
            .toList(),
        maxHighRevolutionTricks: j['maxHighRevolutionTricks'] as int?,
        allowedTrickIds: ((j['allowedTrickIds'] as List<dynamic>?) ?? [])
            .map((id) => id as String)
            .toList(),
      );
```

Replace with:
```dart
class UserPreference {
  final String id;
  final String userId;
  final String name;
  final int? comboLength;
  final int? maxDifficulty;
  final int strongFootPercentage;
  final int? noTouchPercentage;
  final int? maxConsecutiveNoTouch;
  final bool includeCrossOver;
  final bool includeKnee;
  final List<double> allowedRevolutions;
  final int? maxHighRevolutionTricks;
  final List<String> allowedTrickIds;

  const UserPreference({
    required this.id,
    required this.userId,
    required this.name,
    this.comboLength,
    this.maxDifficulty,
    required this.strongFootPercentage,
    this.noTouchPercentage,
    this.maxConsecutiveNoTouch,
    required this.includeCrossOver,
    required this.includeKnee,
    required this.allowedRevolutions,
    this.maxHighRevolutionTricks,
    this.allowedTrickIds = const [],
  });

  factory UserPreference.fromJson(Map<String, dynamic> j) => UserPreference(
        id: (j['id'] as String?) ?? '',
        userId: (j['userId'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        comboLength: j['comboLength'] as int?,
        maxDifficulty: j['maxDifficulty'] as int?,
        strongFootPercentage: j['strongFootPercentage'] as int,
        noTouchPercentage: j['noTouchPercentage'] as int?,
        maxConsecutiveNoTouch: j['maxConsecutiveNoTouch'] as int?,
        includeCrossOver: j['includeCrossOver'] as bool,
        includeKnee: j['includeKnee'] as bool,
        allowedRevolutions:
          ((j['allowedRevolutions'] as List<dynamic>?) ??
              (j['allowedMotions'] as List<dynamic>?) ??
              [])
            .map((m) => (m as num).toDouble())
            .toList(),
        maxHighRevolutionTricks: j['maxHighRevolutionTricks'] as int?,
        allowedTrickIds: ((j['allowedTrickIds'] as List<dynamic>?) ?? [])
            .map((id) => id as String)
            .toList(),
      );
```

- [ ] **Step 2: Update `toJson()` and `copyWith()` signatures**

Find:
```dart
  Map<String, dynamic> toJson() => {
        'name': name,
        'comboLength': comboLength,
        'maxDifficulty': maxDifficulty,
        'strongFootPercentage': strongFootPercentage,
        'noTouchPercentage': noTouchPercentage,
        'maxConsecutiveNoTouch': maxConsecutiveNoTouch,
        'includeCrossOver': includeCrossOver,
        'includeKnee': includeKnee,
        'allowedRevolutions': allowedRevolutions,
        'maxHighRevolutionTricks': maxHighRevolutionTricks,
        'allowedTrickIds': allowedTrickIds,
      };

  UserPreference copyWith({
    String? name,
    int? comboLength,
    int? maxDifficulty,
    int? strongFootPercentage,
    int? noTouchPercentage,
    int? maxConsecutiveNoTouch,
    bool? includeCrossOver,
    bool? includeKnee,
    List<double>? allowedRevolutions,
    int? maxHighRevolutionTricks,
    List<String>? allowedTrickIds,
  }) =>
      UserPreference(
        id: id,
        userId: userId,
        name: name ?? this.name,
        comboLength: comboLength ?? this.comboLength,
        maxDifficulty: maxDifficulty ?? this.maxDifficulty,
        strongFootPercentage: strongFootPercentage ?? this.strongFootPercentage,
        noTouchPercentage: noTouchPercentage ?? this.noTouchPercentage,
        maxConsecutiveNoTouch: maxConsecutiveNoTouch ?? this.maxConsecutiveNoTouch,
        includeCrossOver: includeCrossOver ?? this.includeCrossOver,
        includeKnee: includeKnee ?? this.includeKnee,
        allowedRevolutions: allowedRevolutions ?? this.allowedRevolutions,
        maxHighRevolutionTricks: maxHighRevolutionTricks ?? this.maxHighRevolutionTricks,
        allowedTrickIds: allowedTrickIds ?? this.allowedTrickIds,
      );
}
```

Replace with (unchanged except `toJson`/`copyWith` themselves don't need type edits — `Map<String, dynamic>` and the existing `?? this.X` pattern already tolerate the fields being nullable; only reproduced here so the file's final state is unambiguous):
```dart
  Map<String, dynamic> toJson() => {
        'name': name,
        'comboLength': comboLength,
        'maxDifficulty': maxDifficulty,
        'strongFootPercentage': strongFootPercentage,
        'noTouchPercentage': noTouchPercentage,
        'maxConsecutiveNoTouch': maxConsecutiveNoTouch,
        'includeCrossOver': includeCrossOver,
        'includeKnee': includeKnee,
        'allowedRevolutions': allowedRevolutions,
        'maxHighRevolutionTricks': maxHighRevolutionTricks,
        'allowedTrickIds': allowedTrickIds,
      };

  UserPreference copyWith({
    String? name,
    int? comboLength,
    int? maxDifficulty,
    int? strongFootPercentage,
    int? noTouchPercentage,
    int? maxConsecutiveNoTouch,
    bool? includeCrossOver,
    bool? includeKnee,
    List<double>? allowedRevolutions,
    int? maxHighRevolutionTricks,
    List<String>? allowedTrickIds,
  }) =>
      UserPreference(
        id: id,
        userId: userId,
        name: name ?? this.name,
        comboLength: comboLength ?? this.comboLength,
        maxDifficulty: maxDifficulty ?? this.maxDifficulty,
        strongFootPercentage: strongFootPercentage ?? this.strongFootPercentage,
        noTouchPercentage: noTouchPercentage ?? this.noTouchPercentage,
        maxConsecutiveNoTouch: maxConsecutiveNoTouch ?? this.maxConsecutiveNoTouch,
        includeCrossOver: includeCrossOver ?? this.includeCrossOver,
        includeKnee: includeKnee ?? this.includeKnee,
        allowedRevolutions: allowedRevolutions ?? this.allowedRevolutions,
        maxHighRevolutionTricks: maxHighRevolutionTricks ?? this.maxHighRevolutionTricks,
        allowedTrickIds: allowedTrickIds ?? this.allowedTrickIds,
      );
}
```

(No line changes in this step — confirms the file needs no further edits beyond Step 1. Skip re-writing if `git diff` after Step 1 already shows the file compiles logically; this step exists only to have you re-read and confirm, not to introduce a diff.)

- [ ] **Step 3: Analyze**

Run: `cd mobile && flutter analyze lib/core/models/user_preference.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/core/models/user_preference.dart
git commit -m "$(cat <<'EOF'
Mobile: UserPreference's optional fields become int?

Fixes an unconditional `as int` cast in fromJson that would have thrown
at runtime the first time the API returned null for any of these four
fields (a real bug the pre-implementation audit caught before it shipped).
EOF
)"
```

---

### Task 12: Wire into mobile `preferences_screen.dart`

**Files:**
- Modify: `mobile/lib/features/preferences/preferences_screen.dart`

This is the biggest single-file task in this plan. Work through it in order; each step's `flutter analyze` is your safety net.

- [ ] **Step 1: Fix `_PStat` display and the `flags` caption for null values**

Find:
```dart
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

Replace with:
```dart
    final revRange = pref.allowedRevolutions.isNotEmpty
        ? decodeRevolutionRange(pref.allowedRevolutions)
        : null;
    final flags = '${pref.includeCrossOver ? "Cross-overs" : "No cross-overs"} · '
        '${pref.includeKnee ? "Knee tricks" : "No knee tricks"}'
        '${pref.maxConsecutiveNoTouch != null ? " · Max consec. NT ${pref.maxConsecutiveNoTouch}" : ""}'
        '${pref.maxHighRevolutionTricks != null ? " · Max 3+ rev ${pref.maxHighRevolutionTricks}" : ""}'
        '${revRange != null ? " · Revs ${revRange.min.toStringAsFixed(1)}–${revRange.max.toStringAsFixed(1)}" : ""}'
        '${pref.allowedTrickIds.isNotEmpty ? " · ${pref.allowedTrickIds.length} allowed tricks" : ""}';
```

Find:
```dart
              Expanded(child: _PStat(value: '${pref.comboLength}', label: 'Length')),
              const SizedBox(width: 8),
              Expanded(child: _PStat(value: '${pref.maxDifficulty}', label: 'Max diff')),
              const SizedBox(width: 8),
              Expanded(child: _PStat(value: '${pref.noTouchPercentage}%', label: 'No-touch')),
```

Replace with:
```dart
              Expanded(child: _PStat(value: pref.comboLength != null ? '${pref.comboLength}' : '—', label: 'Length')),
              const SizedBox(width: 8),
              Expanded(child: _PStat(value: pref.maxDifficulty != null ? '${pref.maxDifficulty}' : '—', label: 'Max diff')),
              const SizedBox(width: 8),
              Expanded(child: _PStat(value: pref.noTouchPercentage != null ? '${pref.noTouchPercentage}%' : '—', label: 'No-touch')),
```

- [ ] **Step 2: Add `showLabel` to `_PrefSlider`, so `_OptionalField` can suppress its label without duplicating it**

Find (`_PrefSlider`'s class body):
```dart
class _PrefSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double)? formatValue;

  const _PrefSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.formatValue,
  });
```

Replace with:
```dart
class _PrefSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double)? formatValue;
  final bool showLabel;

  const _PrefSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.formatValue,
    this.showLabel = true,
  });
```

Find (inside `_PrefSlider.build()`):
```dart
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
                      top: 8, left: 0,
                      child: Container(
                        width: (pct * width).clamp(0.0, width),
                        height: 8,
                        decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                    Positioned(
                      left: (pct * width - 12).clamp(0.0, width - 24 < 0 ? 0.0 : width - 24),
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

Replace with (only the first `Row`'s first child changes — `showLabel ? Text(label, ...) : const SizedBox.shrink()` — everything else in this block is unchanged, reproduced in full so the anchor is unambiguous):
```dart
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            showLabel
                ? Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink))
                : const SizedBox.shrink(),
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
                      top: 8, left: 0,
                      child: Container(
                        width: (pct * width).clamp(0.0, width),
                        height: 8,
                        decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                    Positioned(
                      left: (pct * width - 12).clamp(0.0, width - 24 < 0 ? 0.0 : width - 24),
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

- [ ] **Step 3: Same `showLabel` addition to `_PrefRangeSlider`**

Find (`_PrefRangeSlider`'s class body — its constructor):
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
  final bool showLabel;

  const _PrefRangeSlider({
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.showLabel = true,
  });
```

Find (inside `_PrefRangeSlider.build()`, its header row):
```dart
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
```

Replace with (again, only the first `Row`'s first child changes):
```dart
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            showLabel
                ? Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink))
                : const SizedBox.shrink(),
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
```

- [ ] **Step 4: Add the `_OptionalField` widget**

Find:
```dart
class _PrefToggle extends StatelessWidget {
```

Replace with (inserts a new class right before `_PrefToggle`):
```dart
class _OptionalField extends StatelessWidget {
  final String label;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget child;

  const _OptionalField({
    required this.label,
    required this.enabled,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(!enabled),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                IgnorePointer(
                  child: CupertinoSwitch(value: enabled, activeTrackColor: AppColors.indigo, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 11),
          child,
        ],
      ],
    );
  }
}

class _PrefToggle extends StatelessWidget {
```

- [ ] **Step 5: Add per-field `enabled` state, initialize it, and use it on save**

Find:
```dart
  bool _includeCrossOver = true;
  bool _includeKnee = true;
  int _maxHighRevTricks = 1;
  double _revMin = kRevolutionRangeMin;
  double _revMax = kRevolutionRangeMax;
  List<String> _allowedTrickIds = [];
```

Replace with:
```dart
  bool _includeCrossOver = true;
  bool _includeKnee = false;
  int _maxHighRevTricks = 1;
  double _revMin = kRevolutionRangeMin;
  double _revMax = kRevolutionRangeMax;
  bool _comboLengthEnabled = true;
  bool _maxDifficultyEnabled = true;
  bool _noTouchEnabled = true;
  bool _maxConsecEnabled = true;
  bool _maxHighRevEnabled = true;
  bool _revEnabled = false;
  List<String> _allowedTrickIds = [];
```

Find:
```dart
      _nameCtrl.text = p.name;
      _comboLength = p.comboLength;
      _maxDifficulty = p.maxDifficulty;
      _strongFootPct = p.strongFootPercentage;
      _noTouchPct = p.noTouchPercentage;
      _maxConsecNoTouch = p.maxConsecutiveNoTouch;
      _includeCrossOver = p.includeCrossOver;
      _includeKnee = p.includeKnee;
      _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
      final range = decodeRevolutionRange(p.allowedRevolutions);
      _revMin = range.min;
      _revMax = range.max;
      _allowedTrickIds = List.from(p.allowedTrickIds);
    }
  }
```

Replace with:
```dart
      _nameCtrl.text = p.name;
      _comboLengthEnabled = p.comboLength != null;
      _comboLength = p.comboLength ?? 6;
      _maxDifficultyEnabled = p.maxDifficulty != null;
      _maxDifficulty = p.maxDifficulty ?? 10;
      _strongFootPct = p.strongFootPercentage;
      _noTouchEnabled = p.noTouchPercentage != null;
      _noTouchPct = p.noTouchPercentage ?? 30;
      _maxConsecEnabled = p.maxConsecutiveNoTouch != null;
      _maxConsecNoTouch = p.maxConsecutiveNoTouch ?? 2;
      _includeCrossOver = p.includeCrossOver;
      _includeKnee = p.includeKnee;
      _maxHighRevEnabled = p.maxHighRevolutionTricks != null;
      _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
      _revEnabled = p.allowedRevolutions.isNotEmpty;
      final range = decodeRevolutionRange(p.allowedRevolutions);
      _revMin = range.min;
      _revMax = range.max;
      _allowedTrickIds = List.from(p.allowedTrickIds);
    }
  }
```

Find (in `_save()`):
```dart
      final pref = UserPreference(
        id: widget.initial?.id ?? '',
        userId: widget.initial?.userId ?? AuthService.instance.userId ?? '',
        name: name,
        comboLength: _comboLength,
        maxDifficulty: _maxDifficulty,
        strongFootPercentage: _strongFootPct,
        noTouchPercentage: _noTouchPct,
        maxConsecutiveNoTouch: _maxConsecNoTouch,
        includeCrossOver: _includeCrossOver,
        includeKnee: _includeKnee,
        allowedRevolutions: encodeRevolutionRange(_revMin, _revMax),
        maxHighRevolutionTricks: _maxHighRevTricks,
        allowedTrickIds: _allowedTrickIds,
      );
```

Replace with:
```dart
      final pref = UserPreference(
        id: widget.initial?.id ?? '',
        userId: widget.initial?.userId ?? AuthService.instance.userId ?? '',
        name: name,
        comboLength: _comboLengthEnabled ? _comboLength : null,
        maxDifficulty: _maxDifficultyEnabled ? _maxDifficulty : null,
        strongFootPercentage: _strongFootPct,
        noTouchPercentage: _noTouchEnabled ? _noTouchPct : null,
        maxConsecutiveNoTouch: _maxConsecEnabled ? _maxConsecNoTouch : null,
        includeCrossOver: _includeCrossOver,
        includeKnee: _includeKnee,
        allowedRevolutions: _revEnabled ? encodeRevolutionRange(_revMin, _revMax) : [],
        maxHighRevolutionTricks: _maxHighRevEnabled ? _maxHighRevTricks : null,
        allowedTrickIds: _allowedTrickIds,
      );
```

- [ ] **Step 6: Reorder and wrap the form's `build()` method**

Find (from the Name `TextField` through the trick-picker `Material`, i.e. everything between the name field and the error/save-button block):
```dart
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. NT Combinations',
                filled: true,
                fillColor: AppColors.chipBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
              ),
            ),
            const SizedBox(height: 6),
            _PrefSlider(label: 'Combo length', value: _comboLength.toDouble(), min: 1, max: 100, onChanged: (v) => setState(() => _comboLength = v.round())),
            const SizedBox(height: 18),
            _PrefSlider(label: 'Max difficulty', value: _maxDifficulty.toDouble(), min: 1, max: 10, formatValue: (v) => '${v.round()} / 10', onChanged: (v) => setState(() => _maxDifficulty = v.round())),
            const SizedBox(height: 18),
            _PrefSlider(label: 'Strong foot', value: _strongFootPct.toDouble(), min: 0, max: 100, formatValue: (v) => '${v.round()}%', onChanged: (v) => setState(() => _strongFootPct = v.round())),
            const SizedBox(height: 18),
            _PrefSlider(label: 'No-touch', value: _noTouchPct.toDouble(), min: 0, max: 100, formatValue: (v) => '${v.round()}%', onChanged: (v) => setState(() => _noTouchPct = v.round())),
            const SizedBox(height: 18),
            _PrefSlider(label: 'Max consecutive no-touch', value: _maxConsecNoTouch.toDouble(), min: 0, max: 30, onChanged: (v) => setState(() => _maxConsecNoTouch = v.round())),
            const SizedBox(height: 18),
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
            const SizedBox(height: 11),
            _PrefToggle(label: 'Include knee tricks', value: _includeKnee, onChanged: (v) => setState(() => _includeKnee = v)),
            const SizedBox(height: 18),
            Material(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: _showTrickPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _allowedTrickIds.isEmpty
                              ? 'Allowed tricks (all)'
                              : 'Allowed tricks (${_allowedTrickIds.length} selected)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
                    ],
                  ),
                ),
              ),
            ),
```

Replace with:
```dart
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. NT Combinations',
                filled: true,
                fillColor: AppColors.chipBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: _showTrickPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _allowedTrickIds.isEmpty
                              ? 'Allowed tricks (all)'
                              : 'Allowed tricks (${_allowedTrickIds.length} selected)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _OptionalField(
              label: 'Combo length',
              enabled: _comboLengthEnabled,
              onChanged: (v) => setState(() => _comboLengthEnabled = v),
              child: _PrefSlider(
                label: 'Combo length',
                value: _comboLength.toDouble(),
                min: 1, max: 100,
                showLabel: false,
                onChanged: (v) => setState(() => _comboLength = v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _OptionalField(
              label: 'Revolutions',
              enabled: _revEnabled,
              onChanged: (v) => setState(() => _revEnabled = v),
              child: _PrefRangeSlider(
                label: 'Revolutions',
                minValue: _revMin,
                maxValue: _revMax,
                min: kRevolutionRangeMin,
                max: kRevolutionRangeMax,
                step: kRevolutionRangeStep,
                showLabel: false,
                onChanged: (mn, mx) => setState(() { _revMin = mn; _revMax = mx; }),
              ),
            ),
            const SizedBox(height: 18),
            _PrefSlider(label: 'Strong foot', value: _strongFootPct.toDouble(), min: 0, max: 100, formatValue: (v) => '${v.round()}%', onChanged: (v) => setState(() => _strongFootPct = v.round())),
            const SizedBox(height: 18),
            _OptionalField(
              label: 'No-touch',
              enabled: _noTouchEnabled,
              onChanged: (v) => setState(() => _noTouchEnabled = v),
              child: _PrefSlider(
                label: 'No-touch',
                value: _noTouchPct.toDouble(),
                min: 0, max: 100,
                formatValue: (v) => '${v.round()}%',
                showLabel: false,
                onChanged: (v) => setState(() => _noTouchPct = v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _OptionalField(
              label: 'Max consecutive no-touch',
              enabled: _maxConsecEnabled,
              onChanged: (v) => setState(() => _maxConsecEnabled = v),
              child: _PrefSlider(
                label: 'Max consecutive no-touch',
                value: _maxConsecNoTouch.toDouble(),
                min: 0, max: 30,
                showLabel: false,
                onChanged: (v) => setState(() => _maxConsecNoTouch = v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _OptionalField(
              label: 'Max 3+ rev tricks',
              enabled: _maxHighRevEnabled,
              onChanged: (v) => setState(() => _maxHighRevEnabled = v),
              child: _PrefSlider(
                label: 'Max 3+ rev tricks',
                value: _maxHighRevTricks.toDouble(),
                min: 1, max: 15,
                showLabel: false,
                onChanged: (v) => setState(() => _maxHighRevTricks = v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _OptionalField(
              label: 'Max difficulty',
              enabled: _maxDifficultyEnabled,
              onChanged: (v) => setState(() => _maxDifficultyEnabled = v),
              child: _PrefSlider(
                label: 'Max difficulty',
                value: _maxDifficulty.toDouble(),
                min: 1, max: 10,
                formatValue: (v) => '${v.round()} / 10',
                showLabel: false,
                onChanged: (v) => setState(() => _maxDifficulty = v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _PrefToggle(label: 'Include cross-overs', value: _includeCrossOver, onChanged: (v) => setState(() => _includeCrossOver = v)),
            const SizedBox(height: 11),
            _PrefToggle(label: 'Include knee tricks', value: _includeKnee, onChanged: (v) => setState(() => _includeKnee = v)),
```

- [ ] **Step 7: Analyze**

Run: `cd mobile && flutter analyze lib/features/preferences/preferences_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/preferences/preferences_screen.dart
git commit -m "$(cat <<'EOF'
Preference form: optional fields, reorder, knee default off (mobile)

New order: Name, Allowed tricks, Combo length, Revolutions, Strong foot,
No-touch, Max consecutive no-touch, Max 3+ rev tricks, Max difficulty,
Include cross-overs, Include knee tricks. Six fields are now individually
toggleable via a new _OptionalField widget (CupertinoSwitch, matching
_PrefToggle's style) wrapping the existing sliders with showLabel: false
to avoid a duplicate label. Also fixes _PrefCard/_PStat's null-unsafe
string interpolation for these now-nullable fields.
EOF
)"
```

---

### Task 13: Wire into mobile `create_combo_screen.dart`

**Files:**
- Modify: `mobile/lib/features/combos/create_combo_screen.dart`

- [ ] **Step 1: Add `showLabel` to `_AppSlider`**

Find (`_AppSlider`'s constructor):
```dart
class _AppSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final String Function(double)? formatValue;

  const _AppSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
    this.formatValue,
  });
```

Replace with:
```dart
class _AppSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final String Function(double)? formatValue;
  final bool showLabel;

  const _AppSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
    this.formatValue,
    this.showLabel = true,
  });
```

Find (inside `_AppSlider.build()`, its header row):
```dart
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
```

Replace with:
```dart
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            showLabel
                ? Text(label,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink))
                : const SizedBox.shrink(),
            Text(
              valueLabel,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: enabled ? AppColors.indigo : AppColors.faint),
            ),
          ],
        ),
```

- [ ] **Step 2: Same `showLabel` addition to `_AppRangeSlider`**

Find (`_AppRangeSlider`'s constructor):
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
  final bool showLabel;

  const _AppRangeSlider({
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.min,
    required this.max,
    required this.step,
    this.onChanged,
    this.showLabel = true,
  });
```

Find (inside `_AppRangeSlider.build()`, its header row):
```dart
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
```

Replace with:
```dart
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            showLabel
                ? Text(label,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink))
                : const SizedBox.shrink(),
            Text(
              valueLabel,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: enabled ? AppColors.indigo : AppColors.faint),
            ),
          ],
        ),
```

- [ ] **Step 3: Add the `_OptionalField` widget (nullable-`onChanged`/locked variant)**

Find:
```dart
class _AppSlider extends StatelessWidget {
```

Replace with (inserts a new class right before `_AppSlider`):
```dart
class _OptionalField extends StatelessWidget {
  final String label;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Widget child;

  const _OptionalField({
    required this.label,
    required this.enabled,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onChanged == null ? null : () => onChanged!(!enabled),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                IgnorePointer(
                  child: CupertinoSwitch(value: enabled, activeTrackColor: AppColors.indigo, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 11),
          child,
        ],
      ],
    );
  }
}

class _AppSlider extends StatelessWidget {
```

- [ ] **Step 4: Add per-field `enabled` state, flip `includeKnee`'s default**

Find:
```dart
  int _maxHighRevTricks = 1;
  double _revMin = kRevolutionRangeMin;
  double _revMax = kRevolutionRangeMax;
  List<String> _allowedTrickIds = [];
```

Replace with:
```dart
  int _maxHighRevTricks = 1;
  double _revMin = kRevolutionRangeMin;
  double _revMax = kRevolutionRangeMax;
  bool _comboLengthEnabled = true;
  bool _maxDifficultyEnabled = true;
  bool _noTouchEnabled = true;
  bool _maxConsecEnabled = true;
  bool _maxHighRevEnabled = true;
  bool _revEnabled = false;
  List<String> _allowedTrickIds = [];
```

Find (the `_includeKnee` field declaration near the top of `_CreateComboScreenState` — search for `bool _includeKnee = true;`):
```dart
  bool _includeKnee = true;
```

Replace with:
```dart
  bool _includeKnee = false;
```

- [ ] **Step 5: Update the "Custom" chip's reset handler**

Find:
```dart
                            _maxHighRevTricks = 1;
                            _revMin = kRevolutionRangeMin;
                            _revMax = kRevolutionRangeMax;
                            _allowedTrickIds = [];
                          }),
                        ),
```

Replace with:
```dart
                            _maxHighRevTricks = 1;
                            _revMin = kRevolutionRangeMin;
                            _revMax = kRevolutionRangeMax;
                            _comboLengthEnabled = true;
                            _maxDifficultyEnabled = true;
                            _noTouchEnabled = true;
                            _maxConsecEnabled = true;
                            _maxHighRevEnabled = true;
                            _revEnabled = false;
                            _allowedTrickIds = [];
                          }),
                        ),
```

- [ ] **Step 6: Update the saved-preset chip's copy handler**

Find:
```dart
                              _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
                              final range = decodeRevolutionRange(p.allowedRevolutions);
                              _revMin = range.min;
                              _revMax = range.max;
                              _allowedTrickIds = List.from(p.allowedTrickIds);
                            }),
```

Replace with:
```dart
                              _comboLengthEnabled = p.comboLength != null;
                              _comboLength = p.comboLength ?? 6;
                              _maxDifficultyEnabled = p.maxDifficulty != null;
                              _maxDifficulty = p.maxDifficulty ?? 10;
                              _noTouchEnabled = p.noTouchPercentage != null;
                              _noTouchPct = p.noTouchPercentage ?? 30;
                              _maxConsecEnabled = p.maxConsecutiveNoTouch != null;
                              _maxConsecNoTouch = p.maxConsecutiveNoTouch ?? 2;
                              _maxHighRevEnabled = p.maxHighRevolutionTricks != null;
                              _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
                              _revEnabled = p.allowedRevolutions.isNotEmpty;
                              final range = decodeRevolutionRange(p.allowedRevolutions);
                              _revMin = range.min;
                              _revMax = range.max;
                              _allowedTrickIds = List.from(p.allowedTrickIds);
                            }),
```

Note: this replaces the lines that previously did `_comboLength = p.comboLength;` etc. unguarded (the exact compile-error lines the pre-implementation audit flagged) — this step is that fix, folded into the same edit that adds the enabled-flag tracking.

- [ ] **Step 7: Update `_preview()`'s `GenerateComboOverrides` construction**

Find:
```dart
          : GenerateComboOverrides(
              comboLength: _comboLength,
              maxDifficulty: _maxDifficulty,
              strongFootPercentage: _strongFootPct,
              noTouchPercentage: _noTouchPct,
              maxConsecutiveNoTouch: _maxConsecNoTouch,
              includeCrossOver: _includeCrossOver,
              includeKnee: _includeKnee,
              maxHighRevolutionTricks: _maxHighRevTricks,
              allowedTrickIds: _allowedTrickIds,
              allowedRevolutions: encodeRevolutionRange(_revMin, _revMax),
            );
```

Replace with:
```dart
          : GenerateComboOverrides(
              comboLength: _comboLengthEnabled ? _comboLength : null,
              maxDifficulty: _maxDifficultyEnabled ? _maxDifficulty : null,
              strongFootPercentage: _strongFootPct,
              noTouchPercentage: _noTouchEnabled ? _noTouchPct : null,
              maxConsecutiveNoTouch: _maxConsecEnabled ? _maxConsecNoTouch : null,
              includeCrossOver: _includeCrossOver,
              includeKnee: _includeKnee,
              maxHighRevolutionTricks: _maxHighRevEnabled ? _maxHighRevTricks : null,
              allowedTrickIds: _allowedTrickIds,
              allowedRevolutions: _revEnabled ? encodeRevolutionRange(_revMin, _revMax) : [],
            );
```

- [ ] **Step 8: Reorder and wrap the generate view's `build()` method**

Find (from `_FieldLabel('Combo name')` — actually start right after the name field / preset chips, at the first slider — through the AllowedTrickIds picker block):
```dart
                const SizedBox(height: 22),
                _AppSlider(
                  label: 'Combo length',
                  value: _comboLength.toDouble(),
                  min: 1,
                  max: 100,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _comboLength = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'Max difficulty',
                  value: _maxDifficulty.toDouble(),
                  min: 1,
                  max: 10,
                  formatValue: (v) => '${v.round()} / 10',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _maxDifficulty = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'Strong foot',
                  value: _strongFootPct.toDouble(),
                  min: 0,
                  max: 100,
                  formatValue: (v) => '${v.round()}%',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _strongFootPct = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'No-touch',
                  value: _noTouchPct.toDouble(),
                  min: 0,
                  max: 100,
                  formatValue: (v) => '${v.round()}%',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _noTouchPct = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'Max consecutive no-touch',
                  value: _maxConsecNoTouch.toDouble(),
                  min: 0,
                  max: 30,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _maxConsecNoTouch = v.round()),
                ),
                const SizedBox(height: 20),
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
                  value: _includeCrossOver,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _includeCrossOver = v),
                ),
                const SizedBox(height: 11),
                _ToggleRow(
                  label: 'Include knee tricks',
                  value: _includeKnee,
                  onChanged:
                      locked ? null : (v) => setState(() => _includeKnee = v),
                ),
                const SizedBox(height: 20),
                if (locked && selectedPref != null && selectedPref.allowedTrickIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, size: 16, color: AppColors.indigo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Allowed tricks: only ${selectedPref.allowedTrickIds.length} selected in "${selectedPref.name}"',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink2),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!locked)
                  Material(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _showTrickPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
```

This block continues past what's shown — read the file yourself to find its exact closing (the `Material`/`InkWell`/picker-row block ends a few lines after the visible `child: Row(` line, followed by `if (locked)` hint text and then the save button). Move the ENTIRE `if (locked && ...) Container(...) else if (!locked) Material(...)` picker block (both branches) to sit immediately after the "Base preset" chips `SizedBox` (right after its closing `],\n ),\n ),\n ],` for the `if (authed)` block, before `const SizedBox(height: 22),` that precedes the first slider) — i.e. same relative position as "Allowed tricks" moved in the preference form: right after Name/preset selection, before Combo length. Reorder the sliders themselves to: Combo length, Revolutions, Strong foot, No-touch, Max consecutive no-touch, Max 3+ rev tricks, Max difficulty, then the two `_ToggleRow`s — wrapping six of them in `_OptionalField`:

```dart
                const SizedBox(height: 22),
                _OptionalField(
                  label: 'Combo length',
                  enabled: locked ? selectedPref!.comboLength != null : _comboLengthEnabled,
                  onChanged: locked ? null : (v) => setState(() => _comboLengthEnabled = v),
                  child: _AppSlider(
                    label: 'Combo length',
                    value: _comboLength.toDouble(),
                    min: 1,
                    max: 100,
                    showLabel: false,
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _comboLength = v.round()),
                  ),
                ),
                const SizedBox(height: 20),
                _OptionalField(
                  label: 'Revolutions',
                  enabled: locked ? selectedPref!.allowedRevolutions.isNotEmpty : _revEnabled,
                  onChanged: locked ? null : (v) => setState(() => _revEnabled = v),
                  child: _AppRangeSlider(
                    label: 'Revolutions',
                    minValue: _revMin,
                    maxValue: _revMax,
                    min: kRevolutionRangeMin,
                    max: kRevolutionRangeMax,
                    step: kRevolutionRangeStep,
                    showLabel: false,
                    onChanged: locked
                        ? null
                        : (mn, mx) => setState(() {
                              _revMin = mn;
                              _revMax = mx;
                            }),
                  ),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'Strong foot',
                  value: _strongFootPct.toDouble(),
                  min: 0,
                  max: 100,
                  formatValue: (v) => '${v.round()}%',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _strongFootPct = v.round()),
                ),
                const SizedBox(height: 20),
                _OptionalField(
                  label: 'No-touch',
                  enabled: locked ? selectedPref!.noTouchPercentage != null : _noTouchEnabled,
                  onChanged: locked ? null : (v) => setState(() => _noTouchEnabled = v),
                  child: _AppSlider(
                    label: 'No-touch',
                    value: _noTouchPct.toDouble(),
                    min: 0,
                    max: 100,
                    formatValue: (v) => '${v.round()}%',
                    showLabel: false,
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _noTouchPct = v.round()),
                  ),
                ),
                const SizedBox(height: 20),
                _OptionalField(
                  label: 'Max consecutive no-touch',
                  enabled: locked ? selectedPref!.maxConsecutiveNoTouch != null : _maxConsecEnabled,
                  onChanged: locked ? null : (v) => setState(() => _maxConsecEnabled = v),
                  child: _AppSlider(
                    label: 'Max consecutive no-touch',
                    value: _maxConsecNoTouch.toDouble(),
                    min: 0,
                    max: 30,
                    showLabel: false,
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _maxConsecNoTouch = v.round()),
                  ),
                ),
                const SizedBox(height: 20),
                _OptionalField(
                  label: 'Max 3+ rev tricks',
                  enabled: locked ? selectedPref!.maxHighRevolutionTricks != null : _maxHighRevEnabled,
                  onChanged: locked ? null : (v) => setState(() => _maxHighRevEnabled = v),
                  child: _AppSlider(
                    label: 'Max 3+ rev tricks',
                    value: _maxHighRevTricks.toDouble(),
                    min: 1,
                    max: 15,
                    showLabel: false,
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _maxHighRevTricks = v.round()),
                  ),
                ),
                const SizedBox(height: 20),
                _OptionalField(
                  label: 'Max difficulty',
                  enabled: locked ? selectedPref!.maxDifficulty != null : _maxDifficultyEnabled,
                  onChanged: locked ? null : (v) => setState(() => _maxDifficultyEnabled = v),
                  child: _AppSlider(
                    label: 'Max difficulty',
                    value: _maxDifficulty.toDouble(),
                    min: 1,
                    max: 10,
                    formatValue: (v) => '${v.round()} / 10',
                    showLabel: false,
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _maxDifficulty = v.round()),
                  ),
                ),
                const SizedBox(height: 20),
                _ToggleRow(
                  label: 'Include cross-overs',
                  value: _includeCrossOver,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _includeCrossOver = v),
                ),
                const SizedBox(height: 11),
                _ToggleRow(
                  label: 'Include knee tricks',
                  value: _includeKnee,
                  onChanged:
                      locked ? null : (v) => setState(() => _includeKnee = v),
                ),
```

And immediately after the "Base preset" chip row's closing (right where `const SizedBox(height: 22),` used to precede the "Combo length" slider — i.e. BEFORE the block shown above), insert the moved Allowed-tricks picker:
```dart
                const SizedBox(height: 22),
                if (locked && selectedPref != null && selectedPref.allowedTrickIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, size: 16, color: AppColors.indigo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Allowed tricks: only ${selectedPref.allowedTrickIds.length} selected in "${selectedPref.name}"',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink2),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!locked)
                  Material(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _showTrickPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_alt, size: 16, color: AppColors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _allowedTrickIds.isEmpty
                                    ? 'Allowed tricks (all)'
                                    : 'Allowed tricks (${_allowedTrickIds.length} selected)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Fields are locked to the selected preset. Choose "Custom" to edit.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5, color: AppColors.faint),
                    ),
                  ),
```

Read `create_combo_screen.dart` yourself first to find these two blocks' EXACT current boundaries (the picker block's closing braces, the "Fields are locked..." hint's exact current position, and what immediately follows it — a Divider, a Row of buttons, etc.) before making this move, since the plan's prose above describes the target shape but you must confirm you're relocating the right span and not duplicating or dropping the trailing hint / whatever comes after the picker block today. **Do not delete the `if (locked) Padding(...'Fields are locked...')` hint** — it stays, just ends up right after the (now-relocated) picker block instead of at the very end of this Column's field list.

- [ ] **Step 9: Analyze**

Run: `cd mobile && flutter analyze lib/features/combos/create_combo_screen.dart`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add mobile/lib/features/combos/create_combo_screen.dart
git commit -m "$(cat <<'EOF'
Generate quick-overrides: optional fields, reorder, knee default off (mobile)

Same reorder and _OptionalField wrapping as the preference form. When a
saved preset is selected, each toggle reflects and locks to that preset's
own null-ness (enabled/onChanged follow the same locked pattern already
used by every slider here) rather than the local Custom-mode state.
EOF
)"
```

---

### Task 14: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the Preferences API field-list paragraphs**

Find:
```markdown
`MaxHighRevolutionTricks` (`int?`, 1–15, default `1`) caps how many tricks with **3+ revolutions** can appear in one generated/previewed combo — the hardest, rarest moves. No "unlimited" option — always a concrete value in the UI (the field stays nullable server-side only for pre-existing rows saved before this validation range existed). Same field on `UserPreference` and `GenerateComboOverrides` (resolved `Overrides ?? SavedPref ?? null`). Web: number input (min 1, max 15) in both the preference form and the generate-mode custom-overrides panel. Mobile: a plain slider (min 1, max 15, default 1) in both the preference form and generate-mode custom overrides — no separate enable/disable toggle.

`AllowedRevolutions` (`List<decimal>`, default empty) had existed since the multiple-preferences feature but had no UI anywhere until this feature added one: a min–max range slider (0.5–4.0, 0.5 steps) in both the preference form and the generate-mode custom-overrides panel, on web and mobile, following the same locked-when-preset-selected pattern as every other override field. The UI only ever writes a contiguous range — a full-range selection (0.5–4.0) encodes to an empty list, matching the existing "no restriction" semantics, rather than sending the full explicit 8-value list. Web: `RevRangeSlider` (`web/src/components/ui/rev-range-slider.tsx`), a CSS-only dual native-`<input type="range">` control, with `encodeRevolutionRange`/`decodeRevolutionRange` helpers in `web/src/lib/revolutionRange.ts`. Mobile: `_PrefRangeSlider`/`_AppRangeSlider`, hand-rolled two-handle siblings of the existing single-value `_PrefSlider`/`_AppSlider` (the app never uses Flutter's built-in `RangeSlider`), with the same-shaped helpers in `mobile/lib/core/models/revolution_range.dart`.

`AllowedTrickIds` (`List<Guid>`, default empty) restricts combo generation/preview to only these tricks — an empty list means no restriction (full trick pool). Applied in Step 1 pool filtering, after the `AllowedRevolutions` filter: `Overrides?.AllowedTrickIds ?? SavedPref?.AllowedTrickIds ?? []`, only applied `.Where(t => allowedTrickIds.Contains(t.Id))` when non-empty. No validator rule (no existence check, same leniency as `AllowedRevolutions`). Web: `PreferencesPage` has a collapsible `TrickPicker` (search + checkbox list, lazy-loaded via `tricksApi.getAll()`, filtered to non-transition tricks) wired into the preference form only — not currently exposed in the web generate-mode quick-overrides panel. Mobile: `preferences_screen.dart`'s preference form has an "Allowed tricks (N selected)" row that opens a bottom-sheet picker (search + `CheckboxListTile` list, lazy-loaded via `ApiClient.instance.getTricks()`, filtered to non-transition tricks). Mobile's `create_combo_screen.dart` generate view ("Custom" base preset) has the same picker row wired to `GenerateComboOverrides.allowedTrickIds` — when a saved preset is selected instead, the row becomes a read-only banner showing the preset's own allowed-trick count instead of an editable control.
```

Replace with:
```markdown
**Optional fields and field order (preference form + generate-mode "Custom" panel, web + mobile):** `ComboLength`, `MaxDifficulty`, `NoTouchPercentage`, `MaxConsecutiveNoTouch`, `MaxHighRevolutionTricks`, and `AllowedRevolutions` are all individually toggleable — off means the field is `null` (or `[]` for `AllowedRevolutions`) in the request, not a specific number, so combo generation falls back to its hardcoded default (see `GenerateComboHandler.cs`/`PreviewComboHandler.cs`'s `Overrides?.X ?? SavedPref?.X ?? <default>` resolution chain — unchanged by this feature). `StrongFootPercentage` is the only numeric field that stays mandatory. On `UserPreference`, `ComboLength`/`MaxDifficulty`/`NoTouchPercentage`/`MaxConsecutiveNoTouch` are `int?` columns (migration `MakePreferenceFieldsOptional`); `MaxHighRevolutionTricks`/`AllowedRevolutions` were already optional-capable. On `GenerateComboOverrides` every one of these fields was *already* fully nullable/optional on both platforms — the generate screen needed no backend changes for this feature at all.

Field order on both forms: Name → **Allowed tricks** → Combo length → Revolutions → Strong foot → No-touch → Max consecutive no-touch → Max 3+ rev tricks → Max difficulty → Include cross-overs → Include knee tricks (**default now off**, was on). Web: `OptionalField` (`web/src/components/ui/optional-field.tsx`) wraps each toggleable field with a checkbox that shows/hides it; "off" is `null`/`[]` on `PreferencesPage.tsx` (a saved preference's fields), and `undefined` (the override key omitted) on `CreateComboPage.tsx`'s generate panel. Mobile: `_OptionalField` (duplicated per-file per this codebase's existing per-screen-private-widget convention) wraps each field with a `CupertinoSwitch`, reusing the existing sliders with a new `showLabel: false` param (added to `_PrefSlider`/`_AppSlider`/`_PrefRangeSlider`/`_AppRangeSlider`) so the label isn't shown twice. On the generate screen, a toggle's enabled/onChanged reflects and locks to the *selected preset's* own null-ness when one is selected, matching every other field's existing locked-preset pattern.

`AllowedTrickIds` (`List<Guid>`, default empty) restricts combo generation/preview to only these tricks — an empty list means no restriction (full trick pool). Applied in Step 1 pool filtering, after the `AllowedRevolutions` filter: `Overrides?.AllowedTrickIds ?? SavedPref?.AllowedTrickIds ?? []`, only applied `.Where(t => allowedTrickIds.Contains(t.Id))` when non-empty. No validator rule (no existence check, same leniency as `AllowedRevolutions`). Web: `PreferencesPage` has a collapsible `TrickPicker` (search + checkbox list, lazy-loaded via `tricksApi.getAll()`, filtered to non-transition tricks) wired into the preference form only, positioned right after the Name field — not currently exposed in the web generate-mode quick-overrides panel. Mobile: `preferences_screen.dart`'s preference form has an "Allowed tricks (N selected)" row (also right after Name) that opens a bottom-sheet picker (search + `CheckboxListTile` list, lazy-loaded via `ApiClient.instance.getTricks()`, filtered to non-transition tricks). Mobile's `create_combo_screen.dart` generate view ("Custom" base preset) has the same picker row, in the same position, wired to `GenerateComboOverrides.allowedTrickIds` — when a saved preset is selected instead, the row becomes a read-only banner showing the preset's own allowed-trick count instead of an editable control.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
Document optional preference fields, reorder, knee default in CLAUDE.md

EOF
)"
```

---

### Task 15: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Full API test suite**

Run: `cd api && dotnet test`
Expected: `Passed!  - Failed: 0, Passed: 233, Skipped: 0, Total: 233`

- [ ] **Step 2: Full mobile test suite**

Run: `cd mobile && flutter test`
Expected: `All tests passed!` (7 tests — unchanged from before this feature, since no new Dart unit tests were added; this feature is UI-only on the mobile side beyond the model fix).

- [ ] **Step 3: Full web build**

Run: `cd web && npm run build`
Expected: build succeeds, no TypeScript errors.

- [ ] **Step 4: `flutter analyze` on both touched mobile files**

Run: `cd mobile && flutter analyze lib/features/preferences/preferences_screen.dart lib/features/combos/create_combo_screen.dart lib/core/models/user_preference.dart`
Expected: `No issues found!`

- [ ] **Step 5: Manual smoke test (both platforms)**

With `docker-compose up -d` running and the migration applied (Task 1):

1. Web (`cd web && npm run dev`): open Preferences, create a new preference, turn OFF "Max difficulty" and "No-touch," save. Reopen it for editing and confirm those two toggles are still off (round-trip through the API). Turn "Max difficulty" back on and confirm it shows `10` (the reset-on-enable default), not whatever it happened to be before.
2. Web: on Generate → Custom, turn off "Combo length," generate a combo, and check the Network tab — confirm `overrides.comboLength` is absent from the request body (not `null`, not a number).
3. Mobile (`flutter run`): repeat the same two checks — create/edit a preference with a toggle off, and generate with a field off, confirming the toggle states persist and the field is really omitted (a network proxy, or a temporary `print(overrides.toJson())` in `_preview()`, works if no proxy is handy).
4. Both platforms: confirm the new field order matches the spec (Name, Allowed tricks, Combo length, Revolutions, Strong foot, No-touch, Max consecutive no-touch, Max 3+ rev tricks, Max difficulty, Include cross-overs, Include knee tricks) and that a brand-new preference/Custom-generate starts with "Include knee tricks" OFF.
