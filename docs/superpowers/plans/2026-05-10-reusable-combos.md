# Reusable Combos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow admins to mark Public combos as reusable so they appear in the trick picker and can be embedded as collapsed/expandable slots inside new combos.

**Architecture:** `ComboTrick.TrickId` becomes nullable; a new nullable `SubComboId` FK enables a slot to reference either a `Trick` or a `Combo`. A new `PUT /api/combos/{id}/reusable` endpoint (admin-only) toggles the flag. `GET /api/tricks` returns a unified list of tricks and reusable combos. All combo query handlers, the build handler, and the delete guard are updated to handle the new slot type. The web UI gains combo rows in the trick picker, collapsible sub-combo slots in the builder, and an admin reusable toggle.

**Tech Stack:** ASP.NET Core 10 / MediatR / EF Core + Npgsql / FluentValidation / xUnit + FluentAssertions + Moq · React 19 / TypeScript / TanStack Query / Tailwind v4

---

## File Map

### New files
- `api/FreestyleCombo.API/Features/Combos/SetReusable/SetReusableCommand.cs`
- `api/FreestyleCombo.API/Features/Combos/SetReusable/SetReusableHandler.cs`
- `api/FreestyleCombo.Infrastructure/Data/Migrations/<timestamp>_AddReusableCombos.cs` (generated)

### Modified files
| File | Change |
|---|---|
| `api/FreestyleCombo.Core/Entities/Combo.cs` | Add `IsReusable` |
| `api/FreestyleCombo.Core/Entities/ComboTrick.cs` | `TrickId` → `Guid?`, add `SubComboId?`, `SubCombo?` nav, `Trick` → `Trick?` |
| `api/FreestyleCombo.Core/Interfaces/IComboRepository.cs` | Add `GetReusableAsync`, `IsReferencedAsSubComboAsync` |
| `api/FreestyleCombo.Infrastructure/Data/Configurations/ComboTrickConfiguration.cs` | FK for nullable `TrickId` + new `SubComboId` FK |
| `api/FreestyleCombo.Infrastructure/Repositories/ComboRepository.cs` | Implement new methods, update all `ThenInclude` to load `SubCombo` |
| `api/FreestyleCombo.API/Features/Combos/GenerateCombo/GenerateComboResponse.cs` | Update `ComboTrickDto`: `TrickId?`, add `Type`, `SubComboId?`, `SubComboName?`, `SubComboTricks?` |
| `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboCommand.cs` | `BuildComboTrickItem`: `TrickId` → `Guid?`, add `SubComboId?` |
| `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboHandler.cs` | Handle `SubComboId` slots |
| `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboValidator.cs` | Validate exactly one of `TrickId`/`SubComboId` per slot |
| `api/FreestyleCombo.API/Features/Combos/UpdateCombo/UpdateComboHandler.cs` | Handle `SubComboId` slots + flat constraint for reusable combos |
| `api/FreestyleCombo.API/Features/Combos/DeleteCombo/DeleteComboHandler.cs` | Block if referenced as sub-combo |
| `api/FreestyleCombo.API/Features/Combos/GetCombo/GetComboHandler.cs` | Update `ComboTrickDto` mapping |
| `api/FreestyleCombo.API/Features/Combos/GetPublicCombos/GetPublicCombosHandler.cs` | Update mapping + null-safe search |
| `api/FreestyleCombo.API/Features/Combos/GetMyCombos/GetMyCombosHandler.cs` | Update mapping + null-safe search |
| `api/FreestyleCombo.API/Features/Combos/GetPendingComboReviews/GetPendingComboReviewsHandler.cs` | Update mapping |
| `api/FreestyleCombo.API/Features/Combos/GetFavouritedCombos/GetFavouritedCombosHandler.cs` | Update mapping |
| `api/FreestyleCombo.API/Features/Tricks/GetTricks/TrickDto.cs` | Add `TrickListItemDto` |
| `api/FreestyleCombo.API/Features/Tricks/GetTricks/GetTricksQuery.cs` | Return type → `List<TrickListItemDto>` |
| `api/FreestyleCombo.API/Features/Tricks/GetTricks/GetTricksHandler.cs` | Merge tricks + reusable combos |
| `api/FreestyleCombo.API/Controllers/CombosController.cs` | Add `PUT /{id}/reusable` endpoint |
| `api/FreestyleCombo.API/Controllers/TricksController.cs` | Update `ProducesResponseType` |
| `api/FreestyleCombo.Tests/Features/ComboBuildAndVisibilityHandlerTests.cs` | Fix `BuildComboTrickItem` positional calls, add sub-combo tests |
| `api/FreestyleCombo.Tests/Features/DeleteComboHandlerTests.cs` | Add sub-combo guard test |
| `web/src/lib/api/tricks.ts` | Add `TrickListItemDto`, update return types |
| `web/src/lib/api/combos.ts` | Update `ComboTrickDto`, `BuildComboTrickItem`, add `setReusable` |
| `web/src/lib/api/index.ts` | Re-export new types |
| `web/src/features/tricks/TricksPage.tsx` | Combo rows, expand, admin toggle |
| `web/src/features/combos/CreateComboPage.tsx` | Sub-combo slots in picker + builder |
| `web/src/features/combos/ComboDetailPage.tsx` | Render sub-combo slots collapsibly |

---

## Task 1: Entity changes

**Files:**
- Modify: `api/FreestyleCombo.Core/Entities/Combo.cs`
- Modify: `api/FreestyleCombo.Core/Entities/ComboTrick.cs`
- Modify: `api/FreestyleCombo.Infrastructure/Data/Configurations/ComboTrickConfiguration.cs`

- [ ] **Step 1: Update `Combo` entity**

In `api/FreestyleCombo.Core/Entities/Combo.cs`, add after `public string? AiDescription`:

```csharp
public bool IsReusable { get; set; } = false;
```

- [ ] **Step 2: Update `ComboTrick` entity**

Replace the full contents of `api/FreestyleCombo.Core/Entities/ComboTrick.cs`:

```csharp
namespace FreestyleCombo.Core.Entities;

public class ComboTrick
{
    public Guid Id { get; set; }
    public Guid ComboId { get; set; }
    public Guid? TrickId { get; set; }
    public Guid? SubComboId { get; set; }
    public int Position { get; set; }
    public bool StrongFoot { get; set; }
    public bool NoTouch { get; set; }

    public Combo Combo { get; set; } = null!;
    public Trick? Trick { get; set; }
    public Combo? SubCombo { get; set; }
}
```

- [ ] **Step 3: Update `ComboTrickConfiguration`**

Replace full contents of `api/FreestyleCombo.Infrastructure/Data/Configurations/ComboTrickConfiguration.cs`:

```csharp
using FreestyleCombo.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FreestyleCombo.Infrastructure.Data.Configurations;

public class ComboTrickConfiguration : IEntityTypeConfiguration<ComboTrick>
{
    public void Configure(EntityTypeBuilder<ComboTrick> builder)
    {
        builder.HasKey(ct => ct.Id);
        builder.Property(ct => ct.Id).ValueGeneratedOnAdd();

        builder.HasOne(ct => ct.Combo)
            .WithMany(c => c.ComboTricks)
            .HasForeignKey(ct => ct.ComboId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(ct => ct.Trick)
            .WithMany(t => t.ComboTricks)
            .HasForeignKey(ct => ct.TrickId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(ct => ct.SubCombo)
            .WithMany()
            .HasForeignKey(ct => ct.SubComboId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
```

- [ ] **Step 4: Verify the project builds**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet build FreestyleCombo.Infrastructure/FreestyleCombo.Infrastructure.csproj
```

Expected: Build succeeded, 0 errors.

- [ ] **Step 5: Commit**

```bash
git add api/FreestyleCombo.Core/Entities/Combo.cs api/FreestyleCombo.Core/Entities/ComboTrick.cs api/FreestyleCombo.Infrastructure/Data/Configurations/ComboTrickConfiguration.cs
git commit -m "feat: add IsReusable to Combo and SubComboId to ComboTrick entities"
```

---

## Task 2: EF Migration

**Files:**
- Create: `api/FreestyleCombo.Infrastructure/Data/Migrations/<timestamp>_AddReusableCombos.cs` (generated)

- [ ] **Step 1: Generate the migration**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet ef migrations add AddReusableCombos --project FreestyleCombo.Infrastructure --startup-project FreestyleCombo.API
```

Expected: `Done. To undo this action, use 'ef migrations remove'`

- [ ] **Step 2: Add the check constraint manually in the generated migration**

Open the generated `..._AddReusableCombos.cs`. In `Up()`, after the `AddColumn` and `AddForeignKey` calls, append:

```csharp
migrationBuilder.Sql(
    "ALTER TABLE \"ComboTricks\" ADD CONSTRAINT \"CK_ComboTricks_TrickOrSubCombo\" " +
    "CHECK ((\"TrickId\" IS NOT NULL AND \"SubComboId\" IS NULL) OR " +
    "(\"TrickId\" IS NULL AND \"SubComboId\" IS NOT NULL));"
);
```

In `Down()`, before or after the reverse operations, add:

```csharp
migrationBuilder.Sql(
    "ALTER TABLE \"ComboTricks\" DROP CONSTRAINT IF EXISTS \"CK_ComboTricks_TrickOrSubCombo\";"
);
```

- [ ] **Step 3: Apply the migration**

```bash
dotnet ef database update --project FreestyleCombo.Infrastructure --startup-project FreestyleCombo.API
```

Expected: `Done.`

- [ ] **Step 4: Commit**

```bash
git add api/FreestyleCombo.Infrastructure/Data/Migrations/
git commit -m "feat: migration AddReusableCombos — IsReusable, SubComboId FK, check constraint"
```

---

## Task 3: IComboRepository — new methods + eager-load SubCombo

**Files:**
- Modify: `api/FreestyleCombo.Core/Interfaces/IComboRepository.cs`
- Modify: `api/FreestyleCombo.Infrastructure/Repositories/ComboRepository.cs`

- [ ] **Step 1: Add two new methods to the interface**

In `api/FreestyleCombo.Core/Interfaces/IComboRepository.cs`, add after `GetPendingReviewCountAsync`:

```csharp
Task<List<Combo>> GetReusableAsync(CancellationToken ct = default);
Task<bool> IsReferencedAsSubComboAsync(Guid comboId, CancellationToken ct = default);
```

- [ ] **Step 2: Implement both methods in `ComboRepository`**

Add at the end of `ComboRepository`, before the closing brace:

```csharp
public async Task<List<Combo>> GetReusableAsync(CancellationToken ct = default) =>
    await _db.Combos
        .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
        .Where(c => c.IsReusable)
        .OrderBy(c => c.Name)
        .ToListAsync(ct);

public async Task<bool> IsReferencedAsSubComboAsync(Guid comboId, CancellationToken ct = default) =>
    await _db.ComboTricks.AnyAsync(ct2 => ct2.SubComboId == comboId, ct);
```

- [ ] **Step 3: Update all `GetByIdAsync` / `GetPublicAsync` / `GetByOwnerAsync` / `GetAllByOwnerAsync` / `GetFavouritedByUserAsync` / `GetPendingReviewAsync` includes to also load SubCombo**

Every query in `ComboRepository` that does `.Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)` must gain a second include chain. For example `GetByIdAsync`:

```csharp
public async Task<Combo?> GetByIdAsync(Guid id, CancellationToken ct = default) =>
    await _db.Combos
        .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
        .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.SubCombo!)
            .ThenInclude(sc => sc.ComboTricks).ThenInclude(sct => sct.Trick)
        .Include(c => c.Ratings)
        .Include(c => c.Owner)
        .FirstOrDefaultAsync(c => c.Id == id, ct);
```

Apply the same pattern (the extra two `.Include` lines) to `GetPublicAsync`, `GetByOwnerAsync`, `GetAllByOwnerAsync`, `GetFavouritedByUserAsync`, and `GetPendingReviewAsync`.

- [ ] **Step 4: Verify build**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet build
```

Expected: Build succeeded, 0 errors.

- [ ] **Step 5: Commit**

```bash
git add api/FreestyleCombo.Core/Interfaces/IComboRepository.cs api/FreestyleCombo.Infrastructure/Repositories/ComboRepository.cs
git commit -m "feat: add GetReusableAsync and IsReferencedAsSubComboAsync to ComboRepository"
```

---

## Task 4: Update `ComboTrickDto` and add `TrickListItemDto`

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Combos/GenerateCombo/GenerateComboResponse.cs`
- Modify: `api/FreestyleCombo.API/Features/Tricks/GetTricks/TrickDto.cs`
- Modify: `api/FreestyleCombo.API/Features/Tricks/GetTricks/GetTricksQuery.cs`

- [ ] **Step 1: Update `ComboTrickDto` in `GenerateComboResponse.cs`**

Replace the `ComboTrickDto` class with:

```csharp
public class ComboTrickDto
{
    public string Type { get; set; } = "trick";  // "trick" | "combo"

    // Trick slot fields (set when Type == "trick")
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

    // Sub-combo slot fields (set when Type == "combo")
    public Guid? SubComboId { get; set; }
    public string? SubComboName { get; set; }
    public List<ComboTrickDto>? SubComboTricks { get; set; }
}
```

- [ ] **Step 2: Add `TrickListItemDto` to `TrickDto.cs`**

Append to `api/FreestyleCombo.API/Features/Tricks/GetTricks/TrickDto.cs`:

```csharp
public class TrickListItemDto
{
    public string Type { get; set; } = "trick";  // "trick" | "combo"
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;

    // Trick-only fields (null when Type == "combo")
    public string? Abbreviation { get; set; }
    public bool CrossOver { get; set; }
    public bool Knee { get; set; }
    public decimal Revolution { get; set; }
    public int Difficulty { get; set; }
    public int CommonLevel { get; set; }
    public bool IsTransition { get; set; }
    public string? CreatedBy { get; set; }
    public DateOnly? DateCreated { get; set; }
    public string? Notes { get; set; }

    // Combo-only fields (default/null when Type == "trick")
    public double AverageDifficulty { get; set; }
    public int TrickCount { get; set; }
    public List<ComboTrickDto>? Tricks { get; set; }
}
```

- [ ] **Step 3: Update `GetTricksQuery` return type**

In `api/FreestyleCombo.API/Features/Tricks/GetTricks/GetTricksQuery.cs`, change:

```csharp
public record GetTricksQuery(bool? CrossOver, bool? Knee, int? MaxDifficulty) : IRequest<List<TrickDto>>;
```

to:

```csharp
public record GetTricksQuery(bool? CrossOver, bool? Knee, int? MaxDifficulty) : IRequest<List<TrickListItemDto>>;
```

- [ ] **Step 4: Verify build**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet build
```

Expected: Errors about `GetTricksHandler` return type mismatch — these are expected and will be fixed in Task 5.

- [ ] **Step 5: Commit entities and DTOs (partial — let build errors guide next task)**

```bash
git add api/FreestyleCombo.API/Features/Combos/GenerateCombo/GenerateComboResponse.cs api/FreestyleCombo.API/Features/Tricks/GetTricks/TrickDto.cs api/FreestyleCombo.API/Features/Tricks/GetTricks/GetTricksQuery.cs
git commit -m "feat: update ComboTrickDto shape and add TrickListItemDto"
```

---

## Task 5: GetTricks handler — unified response

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Tricks/GetTricks/GetTricksHandler.cs`
- Modify: `api/FreestyleCombo.API/Controllers/TricksController.cs`

- [ ] **Step 1: Write failing test for unified trick list**

Add to `api/FreestyleCombo.Tests/Features/QueryHandlerTests.cs` (or create a new `GetTricksHandlerTests.cs`):

```csharp
using FluentAssertions;
using FreestyleCombo.API.Features.Tricks.GetTricks;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class GetTricksHandlerTests
{
    [Fact]
    public async Task Handle_ReturnsUnifiedListWithTricksAndReusableCombos()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();

        var trick = new Trick { Id = Guid.NewGuid(), Name = "ATW", Abbreviation = "ATW", Difficulty = 2, CommonLevel = 5 };
        var subCombo = new Combo
        {
            Id = Guid.NewGuid(),
            Name = "Basic Foundation",
            IsReusable = true,
            AverageDifficulty = 3.5,
            TrickCount = 2,
            Visibility = ComboVisibility.Public,
            ComboTricks = new List<ComboTrick>
            {
                new() { Id = Guid.NewGuid(), Position = 1, TrickId = trick.Id, Trick = trick }
            }
        };

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync([trick]);
        comboRepo.Setup(r => r.GetReusableAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync([subCombo]);

        var handler = new GetTricksHandler(trickRepo.Object, comboRepo.Object);
        var result = await handler.Handle(new GetTricksQuery(null, null, null), CancellationToken.None);

        result.Should().HaveCount(2);
        result.Should().Contain(i => i.Type == "trick" && i.Name == "ATW");
        var comboItem = result.Single(i => i.Type == "combo");
        comboItem.Name.Should().Be("Basic Foundation");
        comboItem.TrickCount.Should().Be(2);
        comboItem.Tricks.Should().NotBeNull();
    }

    [Fact]
    public async Task Handle_TricksBeforeCombosAlphabetically()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync([new Trick { Id = Guid.NewGuid(), Name = "Zebra Trick", Abbreviation = "ZT" }]);
        comboRepo.Setup(r => r.GetReusableAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync([new Combo { Id = Guid.NewGuid(), Name = "Alpha Combo", IsReusable = true, Visibility = ComboVisibility.Public, ComboTricks = [] }]);

        var handler = new GetTricksHandler(trickRepo.Object, comboRepo.Object);
        var result = await handler.Handle(new GetTricksQuery(null, null, null), CancellationToken.None);

        result[0].Type.Should().Be("trick");
        result[1].Type.Should().Be("combo");
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "GetTricksHandlerTests" 2>&1 | tail -20
```

Expected: compile error or FAIL because handler doesn't accept `IComboRepository` yet.

- [ ] **Step 3: Update `GetTricksHandler`**

Replace full contents of `api/FreestyleCombo.API/Features/Tricks/GetTricks/GetTricksHandler.cs`:

```csharp
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Tricks.GetTricks;

public class GetTricksHandler : IRequestHandler<GetTricksQuery, List<TrickListItemDto>>
{
    private readonly ITrickRepository _trickRepo;
    private readonly IComboRepository _comboRepo;

    public GetTricksHandler(ITrickRepository trickRepo, IComboRepository comboRepo)
    {
        _trickRepo = trickRepo;
        _comboRepo = comboRepo;
    }

    public async Task<List<TrickListItemDto>> Handle(GetTricksQuery request, CancellationToken cancellationToken)
    {
        var tricks = await _trickRepo.GetAllAsync(request.CrossOver, request.Knee, request.MaxDifficulty, cancellationToken);
        var reusableCombos = await _comboRepo.GetReusableAsync(cancellationToken);

        var trickItems = tricks
            .OrderBy(t => t.Name)
            .Select(t => new TrickListItemDto
            {
                Type = "trick",
                Id = t.Id,
                Name = t.Name,
                Abbreviation = t.Abbreviation,
                CrossOver = t.CrossOver,
                Knee = t.Knee,
                Revolution = t.Revolution,
                Difficulty = t.Difficulty,
                CommonLevel = t.CommonLevel,
                IsTransition = t.IsTransition,
                CreatedBy = t.CreatedBy,
                DateCreated = t.DateCreated,
                Notes = t.Notes
            })
            .ToList();

        var comboItems = reusableCombos
            .OrderBy(c => c.Name)
            .Select(c => new TrickListItemDto
            {
                Type = "combo",
                Id = c.Id,
                Name = c.Name ?? string.Empty,
                AverageDifficulty = c.AverageDifficulty,
                TrickCount = c.TrickCount,
                Tricks = c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => new ComboTrickDto
                {
                    Type = "trick",
                    TrickId = ct.TrickId,
                    Name = ct.Trick?.Name,
                    Abbreviation = ct.Trick?.Abbreviation,
                    Position = ct.Position,
                    StrongFoot = ct.StrongFoot,
                    NoTouch = ct.NoTouch,
                    Difficulty = ct.Trick?.Difficulty ?? 0,
                    Revolution = ct.Trick?.Revolution ?? 0,
                    CrossOver = ct.Trick?.CrossOver ?? false,
                    IsTransition = ct.Trick?.IsTransition ?? false
                }).ToList()
            })
            .ToList();

        return [..trickItems, ..comboItems];
    }
}
```

- [ ] **Step 4: Update `TricksController` `ProducesResponseType`**

In `api/FreestyleCombo.API/Controllers/TricksController.cs`, change:

```csharp
[ProducesResponseType(typeof(List<TrickDto>), StatusCodes.Status200OK)]
```

to:

```csharp
[ProducesResponseType(typeof(List<TrickListItemDto>), StatusCodes.Status200OK)]
```

Add the using at the top: `using FreestyleCombo.API.Features.Tricks.GetTricks;`

- [ ] **Step 5: Run tests**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "GetTricksHandlerTests"
```

Expected: 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add api/FreestyleCombo.API/Features/Tricks/ api/FreestyleCombo.API/Controllers/TricksController.cs
git commit -m "feat: GetTricks returns unified trick+reusable-combo list"
```

---

## Task 6: SetReusable feature

**Files:**
- Create: `api/FreestyleCombo.API/Features/Combos/SetReusable/SetReusableCommand.cs`
- Create: `api/FreestyleCombo.API/Features/Combos/SetReusable/SetReusableHandler.cs`
- Modify: `api/FreestyleCombo.API/Controllers/CombosController.cs`

- [ ] **Step 1: Write failing test**

Create `api/FreestyleCombo.Tests/Features/SetReusableHandlerTests.cs`:

```csharp
using FluentAssertions;
using FreestyleCombo.API.Features.Combos.SetReusable;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class SetReusableHandlerTests
{
    private readonly Mock<IComboRepository> _comboRepo = new();

    [Fact]
    public async Task Handle_AdminSetsReusableOnPublicCombo_SetsFlag()
    {
        var comboId = Guid.NewGuid();
        var combo = new Combo { Id = comboId, Visibility = ComboVisibility.Public, IsReusable = false };
        _comboRepo.Setup(r => r.GetByIdAsync(comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        _comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new SetReusableHandler(_comboRepo.Object)
            .Handle(new SetReusableCommand(comboId, true), CancellationToken.None);

        combo.IsReusable.Should().BeTrue();
        _comboRepo.Verify(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_SetReusableOnNonPublicCombo_ThrowsInvalidOperationException()
    {
        var comboId = Guid.NewGuid();
        var combo = new Combo { Id = comboId, Visibility = ComboVisibility.Private, IsReusable = false };
        _comboRepo.Setup(r => r.GetByIdAsync(comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        Func<Task> act = () => new SetReusableHandler(_comboRepo.Object)
            .Handle(new SetReusableCommand(comboId, true), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*Public*");
    }

    [Fact]
    public async Task Handle_UnsetReusable_ClearsFlagRegardlessOfVisibility()
    {
        var comboId = Guid.NewGuid();
        var combo = new Combo { Id = comboId, Visibility = ComboVisibility.Private, IsReusable = true };
        _comboRepo.Setup(r => r.GetByIdAsync(comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        _comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new SetReusableHandler(_comboRepo.Object)
            .Handle(new SetReusableCommand(comboId, false), CancellationToken.None);

        combo.IsReusable.Should().BeFalse();
    }

    [Fact]
    public async Task Handle_ComboNotFound_ThrowsKeyNotFoundException()
    {
        _comboRepo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((Combo?)null);

        Func<Task> act = () => new SetReusableHandler(_comboRepo.Object)
            .Handle(new SetReusableCommand(Guid.NewGuid(), true), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "SetReusableHandlerTests" 2>&1 | tail -10
```

Expected: compile error — `SetReusableCommand` and `SetReusableHandler` not found.

- [ ] **Step 3: Create `SetReusableCommand.cs`**

Create `api/FreestyleCombo.API/Features/Combos/SetReusable/SetReusableCommand.cs`:

```csharp
using MediatR;

namespace FreestyleCombo.API.Features.Combos.SetReusable;

public record SetReusableCommand(Guid ComboId, bool IsReusable) : IRequest;
```

- [ ] **Step 4: Create `SetReusableHandler.cs`**

Create `api/FreestyleCombo.API/Features/Combos/SetReusable/SetReusableHandler.cs`:

```csharp
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.SetReusable;

public class SetReusableHandler : IRequestHandler<SetReusableCommand>
{
    private readonly IComboRepository _repo;

    public SetReusableHandler(IComboRepository repo) => _repo = repo;

    public async Task Handle(SetReusableCommand request, CancellationToken cancellationToken)
    {
        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (request.IsReusable && combo.Visibility != ComboVisibility.Public)
            throw new InvalidOperationException("A combo must be Public before it can be marked reusable.");

        combo.IsReusable = request.IsReusable;
        await _repo.UpdateAsync(combo, cancellationToken);
    }
}
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "SetReusableHandlerTests"
```

Expected: 4 tests PASS.

- [ ] **Step 6: Add controller endpoint**

In `api/FreestyleCombo.API/Controllers/CombosController.cs`:

1. Add using at top: `using FreestyleCombo.API.Features.Combos.SetReusable;`
2. Add endpoint before the closing brace:

```csharp
[HttpPut("{id:guid}/reusable")]
[Authorize(Roles = "Admin")]
[ProducesResponseType(StatusCodes.Status200OK)]
public async Task<IActionResult> SetReusable(Guid id, [FromBody] SetReusableRequest request, CancellationToken ct)
{
    await _mediator.Send(new SetReusableCommand(id, request.IsReusable), ct);
    return Ok();
}
```

3. Add the request record at the bottom of the file:

```csharp
public record SetReusableRequest(bool IsReusable);
```

- [ ] **Step 7: Verify build**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet build
```

Expected: Build succeeded, 0 errors.

- [ ] **Step 8: Commit**

```bash
git add api/FreestyleCombo.API/Features/Combos/SetReusable/ api/FreestyleCombo.API/Controllers/CombosController.cs api/FreestyleCombo.Tests/Features/SetReusableHandlerTests.cs
git commit -m "feat: add SetReusable endpoint — admin can toggle IsReusable on Public combos"
```

---

## Task 7: BuildComboCommand + BuildComboHandler — sub-combo slots

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboCommand.cs`
- Modify: `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboHandler.cs`
- Modify: `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboValidator.cs`
- Modify: `api/FreestyleCombo.Tests/Features/ComboBuildAndVisibilityHandlerTests.cs`

- [ ] **Step 1: Write failing tests for sub-combo slots**

Add to `api/FreestyleCombo.Tests/Features/ComboBuildAndVisibilityHandlerTests.cs` (new test methods):

```csharp
[Fact]
public async Task BuildCombo_WithSubComboSlot_ExpandsTricksForCountAndDifficulty()
{
    var trickRepo = new Mock<ITrickRepository>();
    var comboRepo = new Mock<IComboRepository>();
    var userManager = CreateUserManagerMock();

    var subComboId = Guid.NewGuid();
    var t1 = TrickFaker.Create(difficulty: 2);
    var t2 = TrickFaker.Create(difficulty: 4);
    var subCombo = new Combo
    {
        Id = subComboId,
        Name = "Foundation",
        IsReusable = true,
        Visibility = ComboVisibility.Public,
        AverageDifficulty = 3.0,
        TrickCount = 2,
        ComboTricks =
        [
            new ComboTrick { Id = Guid.NewGuid(), TrickId = t1.Id, Trick = t1, Position = 1 },
            new ComboTrick { Id = Guid.NewGuid(), TrickId = t2.Id, Trick = t2, Position = 2 }
        ]
    };

    trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([]);
    comboRepo.Setup(r => r.GetByIdAsync(subComboId, It.IsAny<CancellationToken>())).ReturnsAsync(subCombo);
    comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
    userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "rafael" });

    var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
    var result = await handler.Handle(
        new BuildComboCommand([new BuildComboTrickItem(null, 1, false, false, subComboId)]),
        CancellationToken.None);

    result.TrickCount.Should().Be(2);
    result.AverageDifficulty.Should().Be(3.0);
    result.Tricks.Should().HaveCount(1);
    result.Tricks[0].Type.Should().Be("combo");
    result.Tricks[0].SubComboId.Should().Be(subComboId);
    result.Tricks[0].SubComboName.Should().Be("Foundation");
    result.Tricks[0].SubComboTricks.Should().HaveCount(2);
}

[Fact]
public async Task BuildCombo_SubComboNotReusable_ThrowsInvalidOperationException()
{
    var trickRepo = new Mock<ITrickRepository>();
    var comboRepo = new Mock<IComboRepository>();
    var userManager = CreateUserManagerMock();

    var subComboId = Guid.NewGuid();
    var notReusable = new Combo { Id = subComboId, IsReusable = false, Visibility = ComboVisibility.Public, ComboTricks = [] };

    trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([]);
    comboRepo.Setup(r => r.GetByIdAsync(subComboId, It.IsAny<CancellationToken>())).ReturnsAsync(notReusable);
    userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "rafael" });

    var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);

    Func<Task> act = () => handler.Handle(
        new BuildComboCommand([new BuildComboTrickItem(null, 1, false, false, subComboId)]),
        CancellationToken.None);

    await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*reusable*");
}

[Fact]
public async Task BuildCombo_DisplayTextIncludesSubComboInBrackets()
{
    var trickRepo = new Mock<ITrickRepository>();
    var comboRepo = new Mock<IComboRepository>();
    var userManager = CreateUserManagerMock();

    var regularTrick = TrickFaker.Create(name: "ATW", difficulty: 2);
    regularTrick = regularTrick with { Abbreviation = "ATW" };

    var subComboId = Guid.NewGuid();
    var innerTrick = TrickFaker.Create(name: "XO", difficulty: 2);
    innerTrick = innerTrick with { Abbreviation = "XO" };

    var subCombo = new Combo
    {
        Id = subComboId,
        Name = "Foundation",
        IsReusable = true,
        Visibility = ComboVisibility.Public,
        ComboTricks = [new ComboTrick { Id = Guid.NewGuid(), TrickId = innerTrick.Id, Trick = innerTrick, Position = 1 }]
    };

    trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([regularTrick]);
    comboRepo.Setup(r => r.GetByIdAsync(subComboId, It.IsAny<CancellationToken>())).ReturnsAsync(subCombo);
    comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
    userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "rafael" });

    var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
    var result = await handler.Handle(
        new BuildComboCommand(
        [
            new BuildComboTrickItem(regularTrick.Id, 1, false, false),
            new BuildComboTrickItem(null, 2, false, false, subComboId)
        ]),
        CancellationToken.None);

    result.DisplayText.Should().Be("ATW [Foundation: XO]");
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "BuildCombo_WithSubComboSlot" 2>&1 | tail -10
```

Expected: compile error — `BuildComboTrickItem` doesn't have `SubComboId` param yet.

- [ ] **Step 3: Update `BuildComboCommand.cs`**

Replace full contents of `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboCommand.cs`:

```csharp
using MediatR;
using FreestyleCombo.API.Features.Combos.GenerateCombo;

namespace FreestyleCombo.API.Features.Combos.BuildCombo;

public record BuildComboCommand(
    List<BuildComboTrickItem> Tricks,
    bool IsPublic = false,
    string? Name = null
) : IRequest<GenerateComboResponse>;

public record BuildComboTrickItem(
    Guid? TrickId,
    int Position,
    bool StrongFoot,
    bool NoTouch,
    Guid? SubComboId = null
);
```

- [ ] **Step 4: Update `BuildComboValidator.cs`**

Replace full contents of `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboValidator.cs`:

```csharp
using FluentValidation;

namespace FreestyleCombo.API.Features.Combos.BuildCombo;

public class BuildComboValidator : AbstractValidator<BuildComboCommand>
{
    public BuildComboValidator()
    {
        RuleFor(x => x.Tricks).NotEmpty().WithMessage("A combo must have at least one trick.");
        RuleForEach(x => x.Tricks).ChildRules(trick =>
        {
            trick.RuleFor(t => t).Must(t =>
                (t.TrickId.HasValue && !t.SubComboId.HasValue) ||
                (!t.TrickId.HasValue && t.SubComboId.HasValue))
                .WithMessage("Each slot must have exactly one of TrickId or SubComboId.");
            trick.RuleFor(t => t.Position).GreaterThanOrEqualTo(1);
        });
    }
}
```

- [ ] **Step 5: Rewrite `BuildComboHandler.cs`**

Replace full contents of `api/FreestyleCombo.API/Features/Combos/BuildCombo/BuildComboHandler.cs`:

```csharp
using System.Security.Claims;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Combos.BuildCombo;

public class BuildComboHandler : IRequestHandler<BuildComboCommand, GenerateComboResponse>
{
    private readonly ITrickRepository _trickRepo;
    private readonly IComboRepository _comboRepo;
    private readonly IHttpContextAccessor _http;
    private readonly UserManager<AppUser> _userManager;

    public BuildComboHandler(ITrickRepository trickRepo, IComboRepository comboRepo, IHttpContextAccessor http, UserManager<AppUser> userManager)
    {
        _trickRepo = trickRepo;
        _comboRepo = comboRepo;
        _http = http;
        _userManager = userManager;
    }

    public async Task<GenerateComboResponse> Handle(BuildComboCommand request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isAdmin = _http.HttpContext.User.IsInRole("Admin");
        var user = await _userManager.FindByIdAsync(userId.ToString());

        // Load regular tricks
        var trickIds = request.Tricks.Where(t => t.TrickId.HasValue).Select(t => t.TrickId!.Value).Distinct().ToList();
        var allTricks = await _trickRepo.GetAllAsync(ct: cancellationToken);
        var trickMap = allTricks.Where(t => trickIds.Contains(t.Id)).ToDictionary(t => t.Id);

        var missingTricks = trickIds.Except(trickMap.Keys).ToList();
        if (missingTricks.Count > 0)
            throw new KeyNotFoundException($"Trick(s) not found: {string.Join(", ", missingTricks)}");

        // Load sub-combos
        var subComboIds = request.Tricks.Where(t => t.SubComboId.HasValue).Select(t => t.SubComboId!.Value).Distinct().ToList();
        var subComboMap = new Dictionary<Guid, Combo>();
        foreach (var scId in subComboIds)
        {
            var sc = await _comboRepo.GetByIdAsync(scId, cancellationToken)
                ?? throw new KeyNotFoundException($"Sub-combo not found: {scId}");
            if (!sc.IsReusable)
                throw new InvalidOperationException($"Combo '{sc.Name}' is not marked as reusable.");
            if (sc.ComboTricks.Any(ct => ct.SubComboId.HasValue))
                throw new InvalidOperationException($"Combo '{sc.Name}' contains nested sub-combos, which is not allowed.");
            subComboMap[scId] = sc;
        }

        var ordered = request.Tricks.OrderBy(t => t.Position).ToList();

        // Expand tricks for count + difficulty (sub-combo tricks count inline)
        var allDifficulties = new List<double>();
        foreach (var slot in ordered)
        {
            if (slot.TrickId.HasValue)
            {
                var trick = trickMap[slot.TrickId.Value];
                allDifficulties.Add((double)trick.Difficulty);
            }
            else
            {
                var sc = subComboMap[slot.SubComboId!.Value];
                allDifficulties.AddRange(sc.ComboTricks.Select(ct => (double)(ct.Trick?.Difficulty ?? 0)));
            }
        }

        var avgDifficulty = allDifficulties.Count > 0 ? Math.Round(allDifficulties.Average(), 1) : 0;
        var totalTrickCount = allDifficulties.Count;

        // Normalize trick slots (strip NoTouch from non-crossover)
        var normalizedTricks = ordered
            .Where(t => t.TrickId.HasValue)
            .Select(t => trickMap[t.TrickId!.Value].IsTransition
                ? t with { NoTouch = false, StrongFoot = false }
                : t with { NoTouch = t.NoTouch && trickMap[t.TrickId!.Value].CrossOver })
            .ToList();

        // Build display text
        var displayParts = ordered.Select(slot =>
        {
            if (slot.TrickId.HasValue)
            {
                var trick = trickMap[slot.TrickId.Value];
                var normalized = normalizedTricks.First(n => n.TrickId == slot.TrickId && n.Position == slot.Position);
                return normalized.NoTouch ? $"{trick.Abbreviation}(nt)" : trick.Abbreviation;
            }
            else
            {
                var sc = subComboMap[slot.SubComboId!.Value];
                var innerParts = sc.ComboTricks.OrderBy(ct => ct.Position)
                    .Select(ct => ct.NoTouch ? $"{ct.Trick?.Abbreviation}(nt)" : ct.Trick?.Abbreviation ?? "?");
                return $"[{sc.Name}: {string.Join(" ", innerParts)}]";
            }
        });
        var displayText = string.Join(" ", displayParts);

        // Build ComboTrick rows to save
        var comboTricks = ordered.Select(t => new ComboTrick
        {
            Id = Guid.NewGuid(),
            TrickId = t.TrickId,
            SubComboId = t.SubComboId,
            Position = t.Position,
            StrongFoot = t.TrickId.HasValue
                ? (trickMap[t.TrickId.Value].IsTransition ? false : t.StrongFoot)
                : false,
            NoTouch = t.TrickId.HasValue
                ? (trickMap[t.TrickId.Value].IsTransition ? false : t.NoTouch && trickMap[t.TrickId.Value].CrossOver)
                : false
        }).ToList();

        var combo = new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = userId,
            Name = string.IsNullOrWhiteSpace(request.Name) ? null : request.Name.Trim(),
            AverageDifficulty = avgDifficulty,
            TrickCount = totalTrickCount,
            Visibility = request.IsPublic
                ? (isAdmin ? ComboVisibility.Public : ComboVisibility.PendingReview)
                : ComboVisibility.Private,
            CreatedAt = DateTime.UtcNow,
            AiDescription = null,
            ComboTricks = comboTricks
        };

        await _comboRepo.AddAsync(combo, cancellationToken);

        // Build response trick DTOs
        var responseTricks = ordered.Select(slot =>
        {
            if (slot.TrickId.HasValue)
            {
                var trick = trickMap[slot.TrickId.Value];
                var normalized = normalizedTricks.First(n => n.TrickId == slot.TrickId && n.Position == slot.Position);
                return new ComboTrickDto
                {
                    Type = "trick",
                    TrickId = trick.Id,
                    Name = trick.Name,
                    Abbreviation = trick.Abbreviation,
                    Position = slot.Position,
                    StrongFoot = normalized.StrongFoot,
                    NoTouch = normalized.NoTouch,
                    Difficulty = trick.Difficulty,
                    Revolution = trick.Revolution,
                    CrossOver = trick.CrossOver,
                    IsTransition = trick.IsTransition
                };
            }
            else
            {
                var sc = subComboMap[slot.SubComboId!.Value];
                return new ComboTrickDto
                {
                    Type = "combo",
                    SubComboId = sc.Id,
                    SubComboName = sc.Name,
                    Position = slot.Position,
                    SubComboTricks = sc.ComboTricks.OrderBy(ct => ct.Position).Select(ct => new ComboTrickDto
                    {
                        Type = "trick",
                        TrickId = ct.TrickId,
                        Name = ct.Trick?.Name,
                        Abbreviation = ct.Trick?.Abbreviation,
                        Position = ct.Position,
                        Difficulty = ct.Trick?.Difficulty ?? 0,
                        Revolution = ct.Trick?.Revolution ?? 0,
                        CrossOver = ct.Trick?.CrossOver ?? false,
                        IsTransition = ct.Trick?.IsTransition ?? false
                    }).ToList()
                };
            }
        }).ToList();

        return new GenerateComboResponse
        {
            Id = combo.Id,
            OwnerId = combo.OwnerId,
            OwnerUserName = user?.UserName,
            Name = combo.Name,
            AverageDifficulty = combo.AverageDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            Visibility = combo.Visibility.ToString(),
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = null,
            Warnings = [],
            Tricks = responseTricks
        };
    }
}
```

- [ ] **Step 6: Fix existing tests broken by `BuildComboTrickItem` positional change**

In `api/FreestyleCombo.Tests/Features/ComboBuildAndVisibilityHandlerTests.cs`, the calls to `new BuildComboTrickItem(trick.Id, 1, true, true)` still work because `TrickId` is now `Guid?` (Guid implicitly converts). Verify by building:

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet build
```

If there are errors about `BuildComboTrickItem`, update each call to use named arguments: `new BuildComboTrickItem(TrickId: trick.Id, Position: 1, StrongFoot: true, NoTouch: false)`.

- [ ] **Step 7: Run all tests**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test
```

Expected: All existing tests PASS plus the 3 new sub-combo tests PASS.

- [ ] **Step 8: Commit**

```bash
git add api/FreestyleCombo.API/Features/Combos/BuildCombo/ api/FreestyleCombo.Tests/Features/ComboBuildAndVisibilityHandlerTests.cs
git commit -m "feat: BuildCombo supports SubComboId slots — expands tricks for count/difficulty/displayText"
```

---

## Task 8: UpdateComboHandler — sub-combo slots + flat constraint

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Combos/UpdateCombo/UpdateComboHandler.cs`

- [ ] **Step 1: Write failing test**

Add to `api/FreestyleCombo.Tests/Features/ComboBuildAndVisibilityHandlerTests.cs`:

```csharp
[Fact]
public async Task UpdateCombo_ReusableComboWithSubComboSlot_ThrowsInvalidOperationException()
{
    var trickRepo = new Mock<ITrickRepository>();
    var comboRepo = new Mock<IComboRepository>();
    var userManager = CreateUserManagerMock();

    var reusableCombo = new Combo
    {
        Id = _comboId, OwnerId = _userId, IsReusable = true,
        Visibility = ComboVisibility.Public, ComboTricks = []
    };
    var subComboId = Guid.NewGuid();

    comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(reusableCombo);
    trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([]);
    userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "rafael" });

    var handler = new UpdateComboHandler(comboRepo.Object, trickRepo.Object, CreateHttp(_userId), userManager.Object);

    Func<Task> act = () => handler.Handle(
        new UpdateComboCommand(_comboId, null, [new BuildComboTrickItem(null, 1, false, false, subComboId)]),
        CancellationToken.None);

    await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*reusable*");
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "UpdateCombo_ReusableComboWithSubComboSlot" 2>&1 | tail -10
```

Expected: FAIL — handler doesn't throw yet.

- [ ] **Step 3: Rewrite `UpdateComboHandler.cs`**

Replace full contents of `api/FreestyleCombo.API/Features/Combos/UpdateCombo/UpdateComboHandler.cs`:

```csharp
using System.Security.Claims;
using FreestyleCombo.API.Features.Combos.BuildCombo;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Combos.UpdateCombo;

public class UpdateComboHandler : IRequestHandler<UpdateComboCommand, GenerateComboResponse>
{
    private readonly IComboRepository _comboRepo;
    private readonly ITrickRepository _trickRepo;
    private readonly IHttpContextAccessor _http;
    private readonly UserManager<AppUser> _userManager;

    public UpdateComboHandler(IComboRepository comboRepo, ITrickRepository trickRepo, IHttpContextAccessor http, UserManager<AppUser> userManager)
    {
        _comboRepo = comboRepo;
        _trickRepo = trickRepo;
        _http = http;
        _userManager = userManager;
    }

    public async Task<GenerateComboResponse> Handle(UpdateComboCommand request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isAdmin = _http.HttpContext.User.IsInRole("Admin");

        var combo = await _comboRepo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (combo.OwnerId != userId && !isAdmin)
            throw new UnauthorizedAccessException("You do not have permission to edit this combo.");

        combo.Name = string.IsNullOrWhiteSpace(request.Name) ? null : request.Name.Trim();

        List<ComboTrick>? newComboTricks = null;
        Dictionary<Guid, Trick>? trickMap = null;
        Dictionary<Guid, Combo>? subComboMap = null;

        if (request.Tricks is { Count: > 0 })
        {
            // Flat constraint: reusable combos cannot contain sub-combo slots
            if (combo.IsReusable && request.Tricks.Any(t => t.SubComboId.HasValue))
                throw new InvalidOperationException("A reusable combo cannot contain sub-combo slots.");

            var trickIds = request.Tricks.Where(t => t.TrickId.HasValue).Select(t => t.TrickId!.Value).Distinct().ToList();
            var allTricks = await _trickRepo.GetAllAsync(ct: cancellationToken);
            trickMap = allTricks.Where(t => trickIds.Contains(t.Id)).ToDictionary(t => t.Id);

            var missingTricks = trickIds.Except(trickMap.Keys).ToList();
            if (missingTricks.Count > 0)
                throw new KeyNotFoundException($"Trick(s) not found: {string.Join(", ", missingTricks)}");

            // Load sub-combos
            var subComboIds = request.Tricks.Where(t => t.SubComboId.HasValue).Select(t => t.SubComboId!.Value).Distinct().ToList();
            subComboMap = new Dictionary<Guid, Combo>();
            foreach (var scId in subComboIds)
            {
                var sc = await _comboRepo.GetByIdAsync(scId, cancellationToken)
                    ?? throw new KeyNotFoundException($"Sub-combo not found: {scId}");
                if (!sc.IsReusable)
                    throw new InvalidOperationException($"Combo '{sc.Name}' is not marked as reusable.");
                subComboMap[scId] = sc;
            }

            var ordered = request.Tricks.OrderBy(t => t.Position).ToList();

            newComboTricks = ordered.Select(t => new ComboTrick
            {
                Id = Guid.NewGuid(),
                ComboId = combo.Id,
                TrickId = t.TrickId,
                SubComboId = t.SubComboId,
                Position = t.Position,
                StrongFoot = t.TrickId.HasValue
                    ? (trickMap[t.TrickId.Value].IsTransition ? false : t.StrongFoot)
                    : false,
                NoTouch = t.TrickId.HasValue
                    ? (trickMap[t.TrickId.Value].IsTransition ? false : t.NoTouch && trickMap[t.TrickId.Value].CrossOver)
                    : false
            }).ToList();

            await _comboRepo.ReplaceComboTricksAsync(combo.Id, newComboTricks, cancellationToken);

            // Expand sub-combo tricks for count + difficulty
            var allDifficulties = new List<double>();
            foreach (var slot in ordered)
            {
                if (slot.TrickId.HasValue)
                    allDifficulties.Add((double)trickMap[slot.TrickId.Value].Difficulty);
                else
                    allDifficulties.AddRange(subComboMap[slot.SubComboId!.Value].ComboTricks
                        .Select(ct => (double)(ct.Trick?.Difficulty ?? 0)));
            }

            combo.TrickCount = allDifficulties.Count;
            combo.AverageDifficulty = allDifficulties.Count > 0 ? Math.Round(allDifficulties.Average(), 1) : 0;
        }

        if (combo.Visibility == ComboVisibility.Public && !isAdmin)
            combo.Visibility = ComboVisibility.PendingReview;

        await _comboRepo.UpdateAsync(combo, cancellationToken);

        var owner = await _userManager.FindByIdAsync(combo.OwnerId.ToString());

        // Build response
        var responseRows = newComboTricks != null
            ? newComboTricks.OrderBy(t => t.Position).ToList()
            : combo.ComboTricks.OrderBy(t => t.Position).ToList();

        var responseTrickMap = trickMap ?? responseRows
            .Where(ct => ct.TrickId.HasValue && ct.Trick != null)
            .ToDictionary(ct => ct.TrickId!.Value, ct => ct.Trick!);

        var responseSubComboMap = subComboMap ?? responseRows
            .Where(ct => ct.SubComboId.HasValue && ct.SubCombo != null)
            .ToDictionary(ct => ct.SubComboId!.Value, ct => ct.SubCombo!);

        var displayParts = responseRows.Select(ct =>
        {
            if (ct.TrickId.HasValue && responseTrickMap.TryGetValue(ct.TrickId.Value, out var trick))
                return ct.NoTouch ? $"{trick.Abbreviation}(nt)" : trick.Abbreviation;
            if (ct.SubComboId.HasValue && responseSubComboMap.TryGetValue(ct.SubComboId.Value, out var sc))
            {
                var inner = sc.ComboTricks.OrderBy(t => t.Position)
                    .Select(t => t.NoTouch ? $"{t.Trick?.Abbreviation}(nt)" : t.Trick?.Abbreviation ?? "?");
                return $"[{sc.Name}: {string.Join(" ", inner)}]";
            }
            return "?";
        });
        var displayText = string.Join(" ", displayParts);

        var trickDtos = responseRows.Select(ct =>
        {
            if (ct.TrickId.HasValue && responseTrickMap.TryGetValue(ct.TrickId.Value, out var trick))
                return new ComboTrickDto
                {
                    Type = "trick",
                    TrickId = trick.Id,
                    Name = trick.Name,
                    Abbreviation = trick.Abbreviation,
                    Position = ct.Position,
                    StrongFoot = ct.StrongFoot,
                    NoTouch = ct.NoTouch,
                    Difficulty = trick.Difficulty,
                    Revolution = trick.Revolution,
                    CrossOver = trick.CrossOver,
                    IsTransition = trick.IsTransition
                };
            if (ct.SubComboId.HasValue && responseSubComboMap.TryGetValue(ct.SubComboId.Value, out var sc))
                return new ComboTrickDto
                {
                    Type = "combo",
                    SubComboId = sc.Id,
                    SubComboName = sc.Name,
                    Position = ct.Position,
                    SubComboTricks = sc.ComboTricks.OrderBy(t => t.Position).Select(t => new ComboTrickDto
                    {
                        Type = "trick",
                        TrickId = t.TrickId,
                        Name = t.Trick?.Name,
                        Abbreviation = t.Trick?.Abbreviation,
                        Position = t.Position,
                        Difficulty = t.Trick?.Difficulty ?? 0,
                        Revolution = t.Trick?.Revolution ?? 0,
                        CrossOver = t.Trick?.CrossOver ?? false,
                        IsTransition = t.Trick?.IsTransition ?? false
                    }).ToList()
                };
            return new ComboTrickDto { Position = ct.Position };
        }).ToList();

        return new GenerateComboResponse
        {
            Id = combo.Id,
            OwnerId = combo.OwnerId,
            OwnerUserName = owner?.UserName,
            Name = combo.Name,
            AverageDifficulty = combo.AverageDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            Visibility = combo.Visibility.ToString(),
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = combo.AiDescription,
            Warnings = [],
            Tricks = trickDtos
        };
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "UpdateCombo"
```

Expected: All UpdateCombo tests PASS including the new flat-constraint test.

- [ ] **Step 5: Commit**

```bash
git add api/FreestyleCombo.API/Features/Combos/UpdateCombo/UpdateComboHandler.cs api/FreestyleCombo.Tests/Features/ComboBuildAndVisibilityHandlerTests.cs
git commit -m "feat: UpdateCombo supports sub-combo slots, enforces flat constraint on reusable combos"
```

---

## Task 9: DeleteCombo sub-combo guard

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Combos/DeleteCombo/DeleteComboHandler.cs`
- Modify: `api/FreestyleCombo.Tests/Features/DeleteComboHandlerTests.cs`

- [ ] **Step 1: Write failing test**

Add to `api/FreestyleCombo.Tests/Features/DeleteComboHandlerTests.cs`:

```csharp
[Fact]
public async Task Handle_ComboReferencedAsSubCombo_ThrowsInvalidOperationException()
{
    SetupUser(_ownerId);
    _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(OwnerCombo());
    _comboRepo.Setup(r => r.IsReferencedAsSubComboAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

    Func<Task> act = () => CreateHandler().Handle(new DeleteComboCommand(_comboId), CancellationToken.None);

    await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*sub-combo*");
}

[Fact]
public async Task Handle_ComboNotReferencedAsSubCombo_Deletes()
{
    SetupUser(_ownerId);
    _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(OwnerCombo());
    _comboRepo.Setup(r => r.IsReferencedAsSubComboAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
    _comboRepo.Setup(r => r.DeleteAsync(_comboId, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

    await CreateHandler().Handle(new DeleteComboCommand(_comboId), CancellationToken.None);

    _comboRepo.Verify(r => r.DeleteAsync(_comboId, It.IsAny<CancellationToken>()), Times.Once);
}
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "ComboReferencedAsSubCombo" 2>&1 | tail -10
```

Expected: FAIL — `IsReferencedAsSubComboAsync` not called yet.

- [ ] **Step 3: Update `DeleteComboHandler.cs`**

Replace full contents:

```csharp
using System.Security.Claims;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.Combos.DeleteCombo;

public class DeleteComboHandler : IRequestHandler<DeleteComboCommand>
{
    private readonly IComboRepository _repo;
    private readonly IHttpContextAccessor _http;

    public DeleteComboHandler(IComboRepository repo, IHttpContextAccessor http)
    {
        _repo = repo;
        _http = http;
    }

    public async Task Handle(DeleteComboCommand request, CancellationToken cancellationToken)
    {
        var user = _http.HttpContext!.User;
        var userId = Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isAdmin = user.IsInRole("Admin");

        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (!isAdmin && combo.OwnerId != userId)
            throw new UnauthorizedAccessException("You do not have permission to delete this combo.");

        var isReferenced = await _repo.IsReferencedAsSubComboAsync(request.ComboId, cancellationToken);
        if (isReferenced)
            throw new InvalidOperationException("This combo is used as a sub-combo in other combos and cannot be deleted.");

        await _repo.DeleteAsync(request.ComboId, cancellationToken);
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --filter "DeleteComboHandlerTests"
```

Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add api/FreestyleCombo.API/Features/Combos/DeleteCombo/DeleteComboHandler.cs api/FreestyleCombo.Tests/Features/DeleteComboHandlerTests.cs
git commit -m "feat: block combo deletion when referenced as a sub-combo"
```

---

## Task 10: Update all combo query handlers for sub-combo slots

**Files:**
- Modify: `api/FreestyleCombo.API/Features/Combos/GetCombo/GetComboHandler.cs`
- Modify: `api/FreestyleCombo.API/Features/Combos/GetPublicCombos/GetPublicCombosHandler.cs`
- Modify: `api/FreestyleCombo.API/Features/Combos/GetMyCombos/GetMyCombosHandler.cs`
- Modify: `api/FreestyleCombo.API/Features/Combos/GetPendingComboReviews/GetPendingComboReviewsHandler.cs`
- Modify: `api/FreestyleCombo.API/Features/Combos/GetFavouritedCombos/GetFavouritedCombosHandler.cs`

All five handlers have the same two problems:
1. `ComboTrickDto` mapping accesses `ct.Trick` directly — will NullReferenceException on sub-combo slots.
2. `DisplayText` building accesses `ct.Trick.Abbreviation` — same problem.

The fix pattern is the same in all five handlers.

- [ ] **Step 1: Create a shared static helper in `GetCombo/GetComboHandler.cs`**

Add this private static method inside `GetComboHandler`:

```csharp
internal static (string DisplayText, List<ComboTrickDto> Tricks) MapComboSlots(IEnumerable<ComboTrick> comboTricks)
{
    var ordered = comboTricks.OrderBy(ct => ct.Position).ToList();

    var displayParts = ordered.Select(ct =>
    {
        if (ct.TrickId.HasValue && ct.Trick != null)
            return ct.NoTouch ? $"{ct.Trick.Abbreviation}(nt)" : ct.Trick.Abbreviation;
        if (ct.SubComboId.HasValue && ct.SubCombo != null)
        {
            var inner = ct.SubCombo.ComboTricks.OrderBy(t => t.Position)
                .Select(t => t.NoTouch ? $"{t.Trick?.Abbreviation}(nt)" : t.Trick?.Abbreviation ?? "?");
            return $"[{ct.SubCombo.Name}: {string.Join(" ", inner)}]";
        }
        return "?";
    });

    var dtos = ordered.Select(ct =>
    {
        if (ct.TrickId.HasValue && ct.Trick != null)
            return new ComboTrickDto
            {
                Type = "trick",
                TrickId = ct.TrickId,
                Name = ct.Trick.Name,
                Abbreviation = ct.Trick.Abbreviation,
                Position = ct.Position,
                StrongFoot = ct.StrongFoot,
                NoTouch = ct.NoTouch,
                Difficulty = ct.Trick.Difficulty,
                Revolution = ct.Trick.Revolution,
                CrossOver = ct.Trick.CrossOver,
                IsTransition = ct.Trick.IsTransition
            };
        if (ct.SubComboId.HasValue && ct.SubCombo != null)
            return new ComboTrickDto
            {
                Type = "combo",
                SubComboId = ct.SubCombo.Id,
                SubComboName = ct.SubCombo.Name,
                Position = ct.Position,
                SubComboTricks = ct.SubCombo.ComboTricks.OrderBy(t => t.Position).Select(t => new ComboTrickDto
                {
                    Type = "trick",
                    TrickId = t.TrickId,
                    Name = t.Trick?.Name,
                    Abbreviation = t.Trick?.Abbreviation,
                    Position = t.Position,
                    Difficulty = t.Trick?.Difficulty ?? 0,
                    Revolution = t.Trick?.Revolution ?? 0,
                    CrossOver = t.Trick?.CrossOver ?? false,
                    IsTransition = t.Trick?.IsTransition ?? false
                }).ToList()
            };
        return new ComboTrickDto { Position = ct.Position };
    }).ToList();

    return (string.Join(" ", displayParts), dtos);
}
```

- [ ] **Step 2: Update `GetComboHandler.Handle` to use the helper**

Replace the `displayText` and `Tricks` assignments in `GetComboHandler.Handle`:

```csharp
var (displayText, tricks) = GetComboHandler.MapComboSlots(combo.ComboTricks);

return new ComboDetailDto
{
    // ... (all existing fields unchanged) ...
    DisplayText = displayText,
    // ...
    Tricks = tricks
};
```

Remove the old inline `displayText` and `Tricks` mapping code.

- [ ] **Step 3: Update the remaining four handlers using the same helper**

Add `using FreestyleCombo.API.Features.Combos.GetCombo;` at the top of each of these files: `GetPublicCombosHandler.cs`, `GetMyCombosHandler.cs`, `GetPendingComboReviewsHandler.cs`, `GetFavouritedCombosHandler.cs`.

In each of those handlers, replace:

```csharp
DisplayText = string.Join(" ", c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => ct.NoTouch ? $"{ct.Trick.Abbreviation}(nt)" : ct.Trick.Abbreviation)),
Tricks = c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => new ComboTrickDto { ... }).ToList(),
```

with:

```csharp
DisplayText = GetComboHandler.MapComboSlots(c.ComboTricks).DisplayText,
Tricks = GetComboHandler.MapComboSlots(c.ComboTricks).Tricks,
```

Also fix the null-unsafe search predicate in `GetPublicCombosHandler`:

```csharp
// OLD:
c.ComboTricks.Any(ct2 => ct2.Trick.Abbreviation.ToLower().Contains(term))
// NEW:
c.ComboTricks.Any(ct2 => ct2.Trick != null && ct2.Trick.Abbreviation.ToLower().Contains(term))
```

And in `GetMyCombosHandler`:

```csharp
// OLD:
c.ComboTricks.Any(ct => ct.Trick.Abbreviation.ToLower().Contains(term))
// NEW:
c.ComboTricks.Any(ct => ct.Trick != null && ct.Trick.Abbreviation.ToLower().Contains(term))
```

- [ ] **Step 4: Run all tests**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test
```

Expected: All tests PASS. Check for 0 failures.

- [ ] **Step 5: Commit**

```bash
git add api/FreestyleCombo.API/Features/Combos/GetCombo/ api/FreestyleCombo.API/Features/Combos/GetPublicCombos/ api/FreestyleCombo.API/Features/Combos/GetMyCombos/ api/FreestyleCombo.API/Features/Combos/GetPendingComboReviews/ api/FreestyleCombo.API/Features/Combos/GetFavouritedCombos/
git commit -m "feat: all combo query handlers render sub-combo slots with bracket DisplayText"
```

---

## Task 11: Full API test run

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --verbosity normal 2>&1 | tail -30
```

Expected: All tests PASS. Total should be > 130 (previous 120 + new tests from Tasks 5, 6, 7, 8, 9).

- [ ] **Step 2: Commit if any fixups were needed; otherwise no commit**

---

## Task 12: Web API client types

**Files:**
- Modify: `web/src/lib/api/tricks.ts`
- Modify: `web/src/lib/api/combos.ts`
- Modify: `web/src/lib/api/index.ts`

- [ ] **Step 1: Update `tricks.ts` — add `TrickListItemDto` and update return type**

In `web/src/lib/api/tricks.ts`, add after the existing `TrickDto` interface:

```typescript
export interface TrickListItemDto {
  type: 'trick' | 'combo'
  id: string
  name: string
  // Trick-only fields
  abbreviation?: string
  crossOver?: boolean
  knee?: boolean
  revolution?: number
  difficulty?: number
  commonLevel?: number
  isTransition?: boolean
  createdBy?: string | null
  dateCreated?: string | null
  notes?: string | null
  // Combo-only fields
  averageDifficulty?: number
  trickCount?: number
  tricks?: import('./combos').ComboTrickDto[]
}
```

Update `tricksApi.getAll` return type:

```typescript
export const tricksApi = {
  getAll: (params?: { crossOver?: boolean; knee?: boolean; maxDifficulty?: number }) =>
    api.get<TrickListItemDto[]>('/tricks', { params }),
  // ... rest unchanged
}
```

- [ ] **Step 2: Update `combos.ts` — update `ComboTrickDto` and `BuildComboTrickItem`**

Replace `ComboTrickDto` interface:

```typescript
export interface ComboTrickDto {
  type?: 'trick' | 'combo'
  position: number
  // Trick slot fields
  trickId?: string
  name?: string
  abbreviation?: string
  strongFoot?: boolean
  noTouch?: boolean
  difficulty?: number
  crossOver?: boolean
  isTransition?: boolean
  // Sub-combo slot fields
  subComboId?: string
  subComboName?: string
  subComboTricks?: ComboTrickDto[]
}
```

Replace `BuildComboTrickItem` interface:

```typescript
export interface BuildComboTrickItem {
  trickId?: string
  subComboId?: string
  position: number
  strongFoot: boolean
  noTouch: boolean
}
```

Add `setReusable` to `combosApi`:

```typescript
setReusable: (id: string, isReusable: boolean) =>
  api.put(`/combos/${id}/reusable`, { isReusable }),
```

- [ ] **Step 3: Re-export from `index.ts`**

In `web/src/lib/api/index.ts`, ensure `TrickListItemDto` is exported. If `index.ts` uses `export * from './tricks'`, it is already covered. Verify:

```bash
grep -n "TrickListItemDto\|export \*" /Users/rafael/Projects/FreestyleCombo/web/src/lib/api/index.ts
```

If `index.ts` does not re-export tricks, add: `export type { TrickListItemDto } from './tricks'`

- [ ] **Step 4: Type-check the web project**

```bash
cd /Users/rafael/Projects/FreestyleCombo/web
npm run build 2>&1 | tail -30
```

Expected: 0 type errors (some component files will need updates — proceed to next tasks).

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/api/
git commit -m "feat: update web API types for TrickListItemDto, ComboTrickDto sub-combo fields, setReusable"
```

---

## Task 13: Web TricksPage — reusable combo rows

**Files:**
- Modify: `web/src/features/tricks/TricksPage.tsx`

- [ ] **Step 1: Import new types and `combosApi`**

At the top of `TricksPage.tsx`, update the import line:

```typescript
import { tricksApi, trickSubmissionsApi, combosApi, extractError, type TrickListItemDto, type TrickDto, type SubmitTrickRequest } from '@/lib/api'
```

- [ ] **Step 2: Update the `tricks` query return type**

The `useQuery` for tricks now returns `TrickListItemDto[]`. Find:

```typescript
const { data: tricks = [], ... } = useQuery({
  queryKey: ['tricks'],
  queryFn: () => tricksApi.getAll().then((r) => r.data),
```

No change needed — the type flows through automatically.

- [ ] **Step 3: Add `expandedComboId` state and `setReusable` mutation**

Inside `TricksPage()`, add after existing state declarations:

```typescript
const [expandedComboId, setExpandedComboId] = useState<string | null>(null)
const adminCheck = isAdmin()

const setReusableMutation = useMutation({
  mutationFn: ({ id, value }: { id: string; value: boolean }) =>
    combosApi.setReusable(id, value),
  onSuccess: () => queryClient.invalidateQueries({ queryKey: ['tricks'] }),
})
```

- [ ] **Step 4: Split the filtered list into tricks and combos**

Replace the existing `filteredTricks` computation with:

```typescript
const filteredItems = (tricks as TrickListItemDto[]).filter(
  (item) =>
    item.name.toLowerCase().includes(search.toLowerCase()) ||
    (item.abbreviation ?? '').toLowerCase().includes(search.toLowerCase()),
)

const filteredTricks = filteredItems.filter((i) => i.type === 'trick') as TrickListItemDto[]
const filteredCombos = filteredItems.filter((i) => i.type === 'combo') as TrickListItemDto[]
```

- [ ] **Step 5: Add combo rows to the table**

In the JSX table body, after rendering trick rows add a section for combo rows. Locate the table's `<tbody>` and after the existing trick `tr` mapping, add:

```tsx
{filteredCombos.map((item) => (
  <React.Fragment key={item.id}>
    <tr
      className="cursor-pointer bg-indigo-50 hover:bg-indigo-100 border-b border-indigo-100"
      onClick={() => setExpandedComboId(expandedComboId === item.id ? null : item.id)}
    >
      <td className="px-4 py-2 font-medium text-indigo-800">
        <span className="inline-flex items-center gap-2">
          <span className="rounded bg-indigo-200 px-1.5 py-0.5 text-xs font-semibold text-indigo-700">combo</span>
          {item.name}
          <span className="text-gray-400 text-xs">({item.trickCount} tricks)</span>
          <span className="text-gray-400 text-xs">{expandedComboId === item.id ? '▲' : '▼'}</span>
        </span>
      </td>
      <td className="px-4 py-2 text-center text-gray-500">—</td>
      <td className="px-4 py-2 text-center text-gray-500">—</td>
      <td className="px-4 py-2 text-center text-gray-500">—</td>
      <td className="px-4 py-2 text-center">
        <span className={`inline-block rounded px-1.5 py-0.5 text-xs font-semibold ${
          (item.averageDifficulty ?? 0) <= 4 ? 'bg-green-100 text-green-800' :
          (item.averageDifficulty ?? 0) <= 7 ? 'bg-yellow-100 text-yellow-800' :
          'bg-red-100 text-red-800'
        }`}>
          {item.averageDifficulty?.toFixed(1)}
        </span>
      </td>
      <td className="px-4 py-2 text-center text-gray-500">—</td>
      {adminCheck && (
        <td className="px-4 py-2 text-center" onClick={(e) => e.stopPropagation()}>
          <input
            type="checkbox"
            checked={true}
            onChange={(e) => setReusableMutation.mutate({ id: item.id, value: e.target.checked })}
            className="cursor-pointer accent-indigo-600"
            title="Reusable"
          />
        </td>
      )}
    </tr>
    {expandedComboId === item.id && (
      <tr className="bg-indigo-50">
        <td colSpan={adminCheck ? 7 : 6} className="px-8 py-2">
          <div className="text-sm text-gray-600 space-y-1">
            {item.tricks?.map((t, i) => (
              <div key={i} className="flex items-center gap-2">
                <span className="font-mono text-xs text-gray-400">{t.position}.</span>
                <span>{t.name}</span>
                <span className="text-gray-400">({t.abbreviation})</span>
                <span className={`rounded px-1 py-0.5 text-xs ${diffColor(t.difficulty ?? 0)}`}>{t.difficulty}</span>
              </div>
            ))}
          </div>
        </td>
      </tr>
    )}
  </React.Fragment>
))}
```

Also add a "Reusable" column header for admins. Find the `<thead>` and add conditionally:

```tsx
{adminCheck && <th className="px-4 py-3 text-center text-xs font-medium uppercase text-gray-500">Reusable</th>}
```

And for non-reusable combo rows shown as admin (Public combos not yet marked reusable), the admin panel in `AdminComboReviewsPage` (Task 14 handles that).

- [ ] **Step 6: Add missing React import**

If not already present at top: `import React from 'react'`

- [ ] **Step 7: Type-check**

```bash
cd /Users/rafael/Projects/FreestyleCombo/web
npx tsc --noEmit 2>&1 | grep -i "TricksPage\|error" | head -20
```

Expected: No errors in TricksPage.

- [ ] **Step 8: Commit**

```bash
git add web/src/features/tricks/TricksPage.tsx
git commit -m "feat: TricksPage shows reusable combo rows with expand and admin reusable toggle"
```

---

## Task 14: Web CreateComboPage — sub-combo slots

**Files:**
- Modify: `web/src/features/combos/CreateComboPage.tsx`

- [ ] **Step 1: Update `SlotItem` type to support sub-combo slots**

Find the `SlotItem` interface at the top of `CreateComboPage.tsx`:

```typescript
interface SlotItem extends BuildComboTrickItem {
  trickName: string
  abbreviation: string
  crossOver: boolean
  isTransition: boolean
}
```

Replace with:

```typescript
interface SlotItem {
  trickId?: string
  subComboId?: string
  position: number
  strongFoot: boolean
  noTouch: boolean
  // Trick fields (set when trickId is present)
  trickName?: string
  abbreviation?: string
  crossOver?: boolean
  isTransition?: boolean
  // Sub-combo fields (set when subComboId is present)
  subComboName?: string
  subComboTrickCount?: number
  subComboTricks?: import('@/lib/api').ComboTrickDto[]
  isSubCombo?: boolean
}
```

- [ ] **Step 2: Import `TrickListItemDto`**

Update the import line:

```typescript
import { combosApi, tricksApi, preferencesApi, extractError, type GenerateComboOverrides, type TrickListItemDto, type BuildComboTrickItem } from '@/lib/api'
```

- [ ] **Step 3: Add `expandedSubComboSlot` state**

Inside `CreateComboPage()`, add:

```typescript
const [expandedSubComboSlot, setExpandedSubComboSlot] = useState<number | null>(null)
```

- [ ] **Step 4: Update `addTrick` to handle both trick and combo items**

Replace existing `addTrick` function:

```typescript
function addItem(item: TrickListItemDto) {
  if (item.type === 'trick') {
    setSlots((prev) => {
      const next = [...prev, {
        trickId: item.id,
        position: prev.length + 1,
        strongFoot: true,
        noTouch: false,
        trickName: item.name,
        abbreviation: item.abbreviation ?? '',
        crossOver: item.crossOver ?? false,
        isTransition: item.isTransition ?? false,
      }]
      return applyNoTouchRules(next)
    })
  } else {
    setSlots((prev) => [...prev, {
      subComboId: item.id,
      position: prev.length + 1,
      strongFoot: false,
      noTouch: false,
      isSubCombo: true,
      subComboName: item.name,
      subComboTrickCount: item.trickCount ?? 0,
      subComboTricks: item.tricks,
    }])
  }
  if (window.innerWidth < 1024) setMobileBuildTab('combo')
}
```

Also update `applyNoTouchRules` to skip sub-combo slots:

```typescript
function applyNoTouchRules(slots: SlotItem[]): SlotItem[] {
  return slots.map((slot, i) => {
    if (slot.isSubCombo) return slot
    const afterTransition = i === 0 || slots[i - 1].isTransition
    return slot.crossOver && !afterTransition && !slot.isTransition ? slot : { ...slot, noTouch: false }
  })
}
```

- [ ] **Step 5: Update `handleSave` / `buildMutation` to pass sub-combo slots**

Update where `slots.map` builds the `BuildComboTrickItem[]` for the API call:

```typescript
const buildMutation = useMutation({
  mutationFn: () =>
    combosApi.build(
      slots.map(({ trickId, subComboId, position, strongFoot, noTouch }) => ({
        trickId: trickId ?? undefined,
        subComboId: subComboId ?? undefined,
        position,
        strongFoot,
        noTouch,
      })),
      isPublic,
      name || undefined,
    ),
  // ... rest unchanged
})
```

Also update the `handleSave` pending combo path:

```typescript
setPendingCombo({
  tricks: slots.map(({ trickId, subComboId, position, strongFoot, noTouch }) => ({
    trickId: trickId ?? undefined,
    subComboId: subComboId ?? undefined,
    position,
    strongFoot,
    noTouch,
  })),
  name: name || undefined,
  isPublic,
})
```

- [ ] **Step 6: Update the trick picker to call `addItem` with the full item**

Find `onClick={() => addTrick(trick)}` (or similar) in the JSX picker list and update each item to call `addItem(item)` where `item` is the `TrickListItemDto`.

Also update `filteredTricks` to `filteredItems`:

```typescript
const filteredItems = (tricks as TrickListItemDto[]).filter(
  (item) =>
    item.name.toLowerCase().includes(search.toLowerCase()) ||
    (item.abbreviation ?? '').toLowerCase().includes(search.toLowerCase()),
)
```

In the picker JSX, map over `filteredItems` and differentiate rendering:

```tsx
{filteredItems.map((item) => (
  <button
    key={item.id}
    onClick={() => addItem(item)}
    className={`w-full text-left rounded-lg border px-3 py-2 text-sm transition-colors hover:border-indigo-400 hover:bg-indigo-50 ${
      item.type === 'combo' ? 'border-indigo-200 bg-indigo-50/50' : 'border-gray-200'
    }`}
  >
    {item.type === 'combo' ? (
      <span className="flex items-center justify-between gap-2">
        <span>
          <span className="rounded bg-indigo-200 px-1 py-0.5 text-xs font-semibold text-indigo-700 mr-1.5">combo</span>
          <span className="font-medium">{item.name}</span>
        </span>
        <span className="text-xs text-gray-400">{item.trickCount} tricks · avg {item.averageDifficulty?.toFixed(1)}</span>
      </span>
    ) : (
      <span className="flex items-center justify-between gap-2">
        <span>{item.name}</span>
        <span className="flex items-center gap-1.5">
          <span className="text-xs text-gray-400">{item.abbreviation}</span>
          <span className={`rounded px-1.5 py-0.5 text-xs font-semibold ${diffColor(item.difficulty ?? 0)}`}>
            {item.difficulty}
          </span>
        </span>
      </span>
    )}
  </button>
))}
```

- [ ] **Step 7: Update the slot renderer to show sub-combo slots as collapsed/expandable**

In the slots list JSX, when rendering each slot, add a branch for `slot.isSubCombo`:

```tsx
{slots.map((slot, index) => (
  <div key={index} className={`...existing classes...`}>
    {slot.isSubCombo ? (
      <div className="flex-1">
        <div className="flex items-center gap-2">
          <span className="rounded bg-indigo-200 px-1.5 py-0.5 text-xs font-semibold text-indigo-700">combo</span>
          <span className="font-medium text-sm">{slot.subComboName}</span>
          <span className="text-xs text-gray-400">{slot.subComboTrickCount} tricks</span>
          <button
            type="button"
            onClick={() => setExpandedSubComboSlot(expandedSubComboSlot === index ? null : index)}
            className="text-xs text-indigo-500 hover:text-indigo-700"
          >
            {expandedSubComboSlot === index ? '▲ hide' : '▼ show'}
          </button>
        </div>
        {expandedSubComboSlot === index && (
          <div className="mt-1 ml-4 space-y-0.5 text-xs text-gray-500">
            {slot.subComboTricks?.map((t, i) => (
              <div key={i}>{t.position}. {t.name} ({t.abbreviation})</div>
            ))}
          </div>
        )}
      </div>
    ) : (
      /* existing trick slot rendering unchanged */
      <div className="flex-1">...</div>
    )}
    {/* remove button stays */}
  </div>
))}
```

- [ ] **Step 8: Update `avgDiff` calculation to handle sub-combo slots**

Replace:

```typescript
const avgDiff = slots.length > 0
  ? slots.reduce((sum, s) => { const tr = tricks.find((tr) => tr.id === s.trickId); return sum + (tr?.difficulty ?? 0) }, 0) / slots.length
  : 0
```

with:

```typescript
const allDiffs: number[] = []
for (const s of slots) {
  if (s.isSubCombo) {
    s.subComboTricks?.forEach((t) => { if (t.difficulty) allDiffs.push(t.difficulty) })
  } else {
    const tr = (tricks as TrickListItemDto[]).find((tr) => tr.id === s.trickId)
    if (tr?.difficulty) allDiffs.push(tr.difficulty)
  }
}
const avgDiff = allDiffs.length > 0 ? allDiffs.reduce((a, b) => a + b, 0) / allDiffs.length : 0
```

- [ ] **Step 9: Type-check**

```bash
cd /Users/rafael/Projects/FreestyleCombo/web
npx tsc --noEmit 2>&1 | grep -i "CreateComboPage\|error" | head -20
```

Expected: 0 errors.

- [ ] **Step 10: Commit**

```bash
git add web/src/features/combos/CreateComboPage.tsx
git commit -m "feat: CreateComboPage supports sub-combo slots — picker shows combos, slots expand inline"
```

---

## Task 15: Web ComboDetailPage — sub-combo slot display

**Files:**
- Modify: `web/src/features/combos/ComboDetailPage.tsx`

- [ ] **Step 1: Add `expandedSubComboIndex` state**

Inside `ComboDetailPage()`, add:

```typescript
const [expandedSubComboIndex, setExpandedSubComboIndex] = useState<number | null>(null)
```

- [ ] **Step 2: Update the trick list rendering to handle sub-combo slots**

Find where `combo.tricks` is rendered (the read-only view, not edit mode). For each trick in the list, add a branch for `type === 'combo'`:

```tsx
{combo.tricks?.map((trick, index) => (
  trick.type === 'combo' ? (
    <div key={index} className="rounded-lg border border-indigo-200 bg-indigo-50 p-2">
      <div className="flex items-center gap-2">
        <span className="text-xs text-gray-400">{trick.position}.</span>
        <span className="rounded bg-indigo-200 px-1.5 py-0.5 text-xs font-semibold text-indigo-700">combo</span>
        <span className="font-medium text-sm">{trick.subComboName}</span>
        <span className="text-xs text-gray-400">{trick.subComboTricks?.length} tricks</span>
        <button
          type="button"
          onClick={() => setExpandedSubComboIndex(expandedSubComboIndex === index ? null : index)}
          className="ml-auto text-xs text-indigo-500 hover:text-indigo-700"
        >
          {expandedSubComboIndex === index ? '▲' : '▼'}
        </button>
      </div>
      {expandedSubComboIndex === index && (
        <div className="mt-1 ml-4 space-y-0.5 text-xs text-gray-500">
          {trick.subComboTricks?.map((t, i) => (
            <div key={i} className="flex items-center gap-1.5">
              <span className="text-gray-400">{t.position}.</span>
              <span>{t.name}</span>
              <span className="text-gray-400">({t.abbreviation})</span>
            </div>
          ))}
        </div>
      )}
    </div>
  ) : (
    /* existing trick row rendering unchanged */
    <div key={index} className="...">...</div>
  )
))}
```

- [ ] **Step 3: Update edit mode `SlotItem` and initialization**

`ComboDetailPage` also has an inline edit mode with its own `SlotItem` interface and `editSlots`. Apply the same `SlotItem` type as in `CreateComboPage.tsx` (copy the interface verbatim). When initializing `editSlots` from `combo.tricks`, map sub-combo slots:

```typescript
setEditSlots(
  (combo.tricks ?? []).map((t) =>
    t.type === 'combo'
      ? {
          subComboId: t.subComboId,
          isSubCombo: true,
          position: t.position,
          strongFoot: false,
          noTouch: false,
          subComboName: t.subComboName,
          subComboTrickCount: t.subComboTricks?.length ?? 0,
          subComboTricks: t.subComboTricks,
        }
      : {
          trickId: t.trickId ?? '',
          position: t.position,
          strongFoot: t.strongFoot ?? false,
          noTouch: t.noTouch ?? false,
          trickName: t.name ?? '',
          abbreviation: t.abbreviation ?? '',
          crossOver: t.crossOver ?? false,
          isTransition: t.isTransition ?? false,
        }
  )
)
```

Also update the save call in edit mode to pass `subComboId`:

```typescript
mutationFn: () =>
  combosApi.update(id!, {
    name: editName || undefined,
    tricks: editSlots.map(({ trickId, subComboId, position, strongFoot, noTouch }) => ({
      trickId: trickId ?? undefined,
      subComboId: subComboId ?? undefined,
      position,
      strongFoot,
      noTouch,
    })),
  }),
```

- [ ] **Step 4: Type-check**

```bash
cd /Users/rafael/Projects/FreestyleCombo/web
npx tsc --noEmit 2>&1 | grep -i "ComboDetailPage\|error" | head -20
```

Expected: 0 errors.

- [ ] **Step 5: Full web build**

```bash
cd /Users/rafael/Projects/FreestyleCombo/web
npm run build 2>&1 | tail -20
```

Expected: Build succeeded, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add web/src/features/combos/ComboDetailPage.tsx
git commit -m "feat: ComboDetailPage renders sub-combo slots as collapsible groups"
```

---

## Task 16: Mobile — reusable combo UI

**Files:**
- Modify: `mobile/lib/core/models/combo.dart`
- Modify: `mobile/lib/core/api/api_client.dart`
- Modify: `mobile/lib/features/tricks/tricks_screen.dart`
- Modify: `mobile/lib/features/combos/create_combo_screen.dart`
- Modify: `mobile/lib/features/combos/combo_detail_screen.dart`

- [ ] **Step 1: Update `ComboTrickDto` in `combo.dart`**

Find the `ComboTrickDto` class in `mobile/lib/core/models/combo.dart`. Add the sub-combo fields:

```dart
class ComboTrickDto {
  final String type;            // "trick" | "combo"
  final int position;
  // Trick fields
  final String? trickId;
  final String? name;
  final String? abbreviation;
  final bool strongFoot;
  final bool noTouch;
  final int difficulty;
  final bool crossOver;
  final bool isTransition;
  // Sub-combo fields
  final String? subComboId;
  final String? subComboName;
  final List<ComboTrickDto>? subComboTricks;

  const ComboTrickDto({
    this.type = 'trick',
    required this.position,
    this.trickId,
    this.name,
    this.abbreviation,
    this.strongFoot = false,
    this.noTouch = false,
    this.difficulty = 0,
    this.crossOver = false,
    this.isTransition = false,
    this.subComboId,
    this.subComboName,
    this.subComboTricks,
  });

  factory ComboTrickDto.fromJson(Map<String, dynamic> json) => ComboTrickDto(
    type: json['type'] as String? ?? 'trick',
    position: json['position'] as int,
    trickId: json['trickId'] as String?,
    name: json['name'] as String?,
    abbreviation: json['abbreviation'] as String?,
    strongFoot: json['strongFoot'] as bool? ?? false,
    noTouch: json['noTouch'] as bool? ?? false,
    difficulty: json['difficulty'] as int? ?? 0,
    crossOver: json['crossOver'] as bool? ?? false,
    isTransition: json['isTransition'] as bool? ?? false,
    subComboId: json['subComboId'] as String?,
    subComboName: json['subComboName'] as String?,
    subComboTricks: (json['subComboTricks'] as List<dynamic>?)
        ?.map((e) => ComboTrickDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
```

Also add a `TrickListItemDto` model alongside the existing trick models:

```dart
class TrickListItemDto {
  final String type;  // "trick" | "combo"
  final String id;
  final String name;
  final String? abbreviation;
  final bool crossOver;
  final bool knee;
  final double revolution;
  final int difficulty;
  final int commonLevel;
  final bool isTransition;
  final double averageDifficulty;
  final int trickCount;
  final List<ComboTrickDto> tricks;

  const TrickListItemDto({
    required this.type,
    required this.id,
    required this.name,
    this.abbreviation,
    this.crossOver = false,
    this.knee = false,
    this.revolution = 0,
    this.difficulty = 0,
    this.commonLevel = 0,
    this.isTransition = false,
    this.averageDifficulty = 0,
    this.trickCount = 0,
    this.tricks = const [],
  });

  factory TrickListItemDto.fromJson(Map<String, dynamic> json) => TrickListItemDto(
    type: json['type'] as String? ?? 'trick',
    id: json['id'] as String,
    name: json['name'] as String,
    abbreviation: json['abbreviation'] as String?,
    crossOver: json['crossOver'] as bool? ?? false,
    knee: json['knee'] as bool? ?? false,
    revolution: (json['revolution'] as num?)?.toDouble() ?? 0,
    difficulty: json['difficulty'] as int? ?? 0,
    commonLevel: json['commonLevel'] as int? ?? 0,
    isTransition: json['isTransition'] as bool? ?? false,
    averageDifficulty: (json['averageDifficulty'] as num?)?.toDouble() ?? 0,
    trickCount: json['trickCount'] as int? ?? 0,
    tricks: (json['tricks'] as List<dynamic>? ?? [])
        .map((e) => ComboTrickDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
```

- [ ] **Step 2: Update `api_client.dart` — update tricks endpoint and add setReusable**

Find the `getTricks` method. Update its return type to `List<TrickListItemDto>`:

```dart
Future<List<TrickListItemDto>> getTricks({bool? crossOver, bool? knee, int? maxDifficulty}) async {
  final params = <String, dynamic>{};
  if (crossOver != null) params['crossOver'] = crossOver;
  if (knee != null) params['knee'] = knee;
  if (maxDifficulty != null) params['maxDifficulty'] = maxDifficulty;
  final resp = await _dio.get('/tricks', queryParameters: params.isEmpty ? null : params);
  return (resp.data as List).map((e) => TrickListItemDto.fromJson(e as Map<String, dynamic>)).toList();
}
```

Add `setReusable`:

```dart
Future<void> setReusable(String comboId, bool isReusable) async {
  await _dio.put('/combos/$comboId/reusable', data: {'isReusable': isReusable});
}
```

Also update `buildCombo` to accept `subComboId`:

The `BuildComboTrickItem.toJson()` in `combo.dart` should include `subComboId`:

```dart
Map<String, dynamic> toJson() => {
  if (trickId != null) 'trickId': trickId,
  if (subComboId != null) 'subComboId': subComboId,
  'position': position,
  'strongFoot': strongFoot,
  'noTouch': noTouch,
};
```

Update `BuildComboTrickItem` to add `subComboId`:

```dart
class BuildComboTrickItem {
  final String? trickId;
  final String? subComboId;
  final int position;
  final bool strongFoot;
  final bool noTouch;

  const BuildComboTrickItem({
    this.trickId,
    this.subComboId,
    required this.position,
    required this.strongFoot,
    required this.noTouch,
  });

  Map<String, dynamic> toJson() => {
    if (trickId != null) 'trickId': trickId,
    if (subComboId != null) 'subComboId': subComboId,
    'position': position,
    'strongFoot': strongFoot,
    'noTouch': noTouch,
  };
}
```

- [ ] **Step 3: Update `tricks_screen.dart`**

Update `setState` that sets `_tricks` to use `TrickListItemDto`. Split the list into tricks and combos. For the trick table, render combo rows differently:

```dart
// Separate lists
final trickItems = _tricks.where((t) => t.type == 'trick').toList();
final comboItems = _tricks.where((t) => t.type == 'combo').toList();
```

After the existing tricks `ListView`, add a section for combo rows. Each combo row is a `ListTile` with a trailing expand `IconButton`. On expand, show its `tricks` list inline in an `ExpansionTile`.

For admins, show a `Switch` on each combo row to toggle `isReusable`.

Full implementation using `ExpansionTile`:

```dart
...ExpansionTile entries for comboItems...
ExpansionTile(
  title: Row(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(4)),
      child: Text('combo', style: TextStyle(fontSize: 11, color: Colors.indigo.shade800, fontWeight: FontWeight.w600)),
    ),
    const SizedBox(width: 8),
    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
    const SizedBox(width: 8),
    Text('${item.trickCount} tricks', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
  ]),
  trailing: _isAdmin
    ? Switch(
        value: true,  // item is already reusable since it's in the list
        onChanged: (val) async {
          await ApiClient.instance.setReusable(item.id, val);
          _loadTricks();
        },
      )
    : const Icon(Icons.expand_more),
  children: item.tricks.map((t) => ListTile(
    dense: true,
    leading: Text('${t.position}.', style: TextStyle(color: Colors.grey.shade500)),
    title: Text(t.name ?? ''),
    trailing: Text(t.abbreviation ?? ''),
  )).toList(),
),
```

- [ ] **Step 4: Update `create_combo_screen.dart` — sub-combo slots**

The `_PickedTrick` or equivalent slot model needs a `subComboId` field. Add:

```dart
// In the slot state model (whatever it's called in this file):
final String? subComboId;
final String? subComboName;
final int? subComboTrickCount;
final List<ComboTrickDto>? subComboTricks;
final bool isSubCombo;
```

In the picker list, combo items (`type == 'combo'`) call a separate `_addComboSlot(TrickListItemDto)` method that appends a slot with `isSubCombo: true`.

In the slot list rendering, `isSubCombo` slots render as a collapsed `ExpansionTile` showing the combo name and trick count; expanding shows the inner tricks read-only.

- [ ] **Step 5: Update `combo_detail_screen.dart` — sub-combo slot display**

Find where `combo.tricks` is rendered. For each trick, check `trick.type == 'combo'` and render an `ExpansionTile`:

```dart
trick.type == 'combo'
  ? ExpansionTile(
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(4)),
          child: Text('combo', style: TextStyle(fontSize: 11, color: Colors.indigo.shade800, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Text(trick.subComboName ?? ''),
        const SizedBox(width: 6),
        Text('${trick.subComboTricks?.length ?? 0} tricks', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ]),
      children: (trick.subComboTricks ?? []).map((t) => ListTile(
        dense: true,
        leading: Text('${t.position}.', style: TextStyle(color: Colors.grey.shade500)),
        title: Text(t.name ?? ''),
        trailing: Text(t.abbreviation ?? ''),
      )).toList(),
    )
  : /* existing trick ListTile rendering */
```

- [ ] **Step 6: Flutter build check**

```bash
cd /Users/rafael/Projects/FreestyleCombo/mobile
flutter build apk --debug 2>&1 | tail -20
```

Expected: Build succeeded.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/
git commit -m "feat: mobile supports sub-combo slots in tricks list, builder, and combo detail"
```

---

## Task 17: Final full verification

- [ ] **Step 1: Run all API tests**

```bash
cd /Users/rafael/Projects/FreestyleCombo/api
dotnet test --verbosity normal 2>&1 | tail -10
```

Expected: All tests PASS, no failures.

- [ ] **Step 2: Build the web project**

```bash
cd /Users/rafael/Projects/FreestyleCombo/web
npm run build 2>&1 | tail -10
```

Expected: Build succeeded, 0 errors.

- [ ] **Step 3: Update `CLAUDE.md`**

In the `CLAUDE.md` file, update the following sections:

1. Under **Entities**, update `ComboTrick` row: add `SubComboId?` and `SubCombo?` nav.
2. Under **Entities**, update `Combo` row: add `IsReusable (bool, default false)`.
3. Under **Combos extra endpoints**, add the new row:
   ```
   | `PUT` | `/api/combos/{id}/reusable` | Admin | Set/unset IsReusable flag (requires Visibility == Public) |
   ```
4. Under **Tricks API**, update the `GET /` description to mention the unified list.
5. Under **Tests**, update the count (was 120, now higher).

- [ ] **Step 4: Final commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for reusable combos feature"
```
