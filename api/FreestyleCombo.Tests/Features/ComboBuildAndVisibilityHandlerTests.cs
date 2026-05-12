using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.API.Features.Combos.BuildCombo;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.PreviewCombo;
using FreestyleCombo.API.Features.Combos.UpdateVisibility;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class ComboBuildAndVisibilityHandlerTests
{
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _comboId = Guid.NewGuid();

    private static Mock<UserManager<AppUser>> CreateUserManagerMock()
    {
        return new Mock<UserManager<AppUser>>(
            Mock.Of<IUserStore<AppUser>>(),
            null!, null!, null!, null!, null!, null!, null!, null!);
    }

    private static IHttpContextAccessor CreateHttp(Guid userId, bool isAdmin = false)
    {
        var claims = new List<Claim> { new(ClaimTypes.NameIdentifier, userId.ToString()) };
        if (isAdmin)
        {
            claims.Add(new Claim(ClaimTypes.Role, "Admin"));
        }

        return new HttpContextAccessor
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(claims, "test"))
            }
        };
    }

    [Fact]
    public async Task BuildCombo_BuildsPrivateComboAndStripsNoTouchFromNonCrossOver()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        var trick = TrickFaker.Create(name: "ATW", crossOver: false, revolution: 1.0m, difficulty: 2, commonLevel: 4);
        Combo? savedCombo = null;

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([trick]);
        comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>()))
            .Callback<Combo, CancellationToken>((combo, _) => savedCombo = combo)
            .Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "rafael" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        var result = await handler.Handle(
            new BuildComboCommand([new BuildComboTrickItem(trick.Id, null, 1, true, true)], false, "  My Combo  "),
            CancellationToken.None);

        savedCombo.Should().NotBeNull();
        savedCombo!.Visibility.Should().Be(ComboVisibility.Private);
        savedCombo.Name.Should().Be("My Combo");
        savedCombo.ComboTricks.Single().NoTouch.Should().BeFalse();
        result.DisplayText.Should().Be(trick.Abbreviation);
        result.OwnerUserName.Should().Be("rafael");
    }

    [Fact]
    public async Task BuildCombo_PublicByUser_SetsPendingReview()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        var trick = TrickFaker.Create(crossOver: true, difficulty: 3);
        Combo? savedCombo = null;

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([trick]);
        comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>()))
            .Callback<Combo, CancellationToken>((combo, _) => savedCombo = combo)
            .Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "rafael" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        await handler.Handle(new BuildComboCommand([new BuildComboTrickItem(trick.Id, null, 1, true, false)], true), CancellationToken.None);

        savedCombo!.Visibility.Should().Be(ComboVisibility.PendingReview);
    }

    [Fact]
    public async Task BuildCombo_MissingTrick_ThrowsKeyNotFoundException()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "rafael" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        var missingId = Guid.NewGuid();

        Func<Task> act = () => handler.Handle(new BuildComboCommand([new BuildComboTrickItem(missingId, null, 1, true, false)]), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task UpdateVisibility_UserMakingComboPublic_SetsPendingReview()
    {
        var repo = new Mock<IComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _userId, Visibility = ComboVisibility.Private };
        repo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        repo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new UpdateVisibilityHandler(repo.Object, CreateHttp(_userId))
            .Handle(new UpdateVisibilityCommand(_comboId, _userId, true), CancellationToken.None);

        combo.Visibility.Should().Be(ComboVisibility.PendingReview);
    }

    [Fact]
    public async Task UpdateVisibility_NonOwner_ThrowsUnauthorizedAccessException()
    {
        var repo = new Mock<IComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = Guid.NewGuid(), Visibility = ComboVisibility.Private };
        repo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        Func<Task> act = () => new UpdateVisibilityHandler(repo.Object, CreateHttp(_userId))
            .Handle(new UpdateVisibilityCommand(_comboId, _userId, true), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("You do not own this combo.");
    }

    [Fact]
    public async Task UpdateVisibility_NonAdminMakingPublicComboPrivate_ThrowsUnauthorizedAccessException()
    {
        var repo = new Mock<IComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _userId, Visibility = ComboVisibility.Public };
        repo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        Func<Task> act = () => new UpdateVisibilityHandler(repo.Object, CreateHttp(_userId))
            .Handle(new UpdateVisibilityCommand(_comboId, _userId, false), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("Only admins can make a public combo private.");
    }

    [Fact]
    public async Task PreviewCombo_WithSavedPreference_ReturnsOrderedPreview()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var prefRepo = new Mock<IUserPreferenceRepository>();
        var prefId = Guid.NewGuid();
        var tricks = new List<Trick>
        {
            TrickFaker.Create(name: "ATW", crossOver: false, difficulty: 1, commonLevel: 4, revolution: 1.0m),
            TrickFaker.Create(name: "MATW", crossOver: true, difficulty: 2, commonLevel: 4, revolution: 2.0m),
            TrickFaker.Create(name: "LATW", crossOver: false, difficulty: 1, commonLevel: 3, revolution: 1.0m)
        };
        prefRepo.Setup(r => r.GetByIdAsync(prefId, It.IsAny<CancellationToken>())).ReturnsAsync(new UserPreference
        {
            Id = prefId,
            UserId = _userId,
            ComboLength = 3,
            MaxDifficulty = 3,
            StrongFootPercentage = 50,
            NoTouchPercentage = 0,
            MaxConsecutiveNoTouch = 1,
            IncludeCrossOver = true,
            IncludeKnee = true,
            AllowedRevolutions = []
        });
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync(tricks);

        var result = await new PreviewComboHandler(trickRepo.Object, prefRepo.Object, CreateHttp(_userId))
            .Handle(new PreviewComboCommand(prefId, null), CancellationToken.None);

        result.Tricks.Should().HaveCount(3);
        result.Tricks.Select(t => t.Position).Should().Equal([1, 2, 3]);
    }

    [Fact]
    public async Task PreviewCombo_InvalidPreference_ThrowsKeyNotFoundException()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var prefRepo = new Mock<IUserPreferenceRepository>();
        var prefId = Guid.NewGuid();
        prefRepo.Setup(r => r.GetByIdAsync(prefId, It.IsAny<CancellationToken>())).ReturnsAsync(new UserPreference
        {
            Id = prefId,
            UserId = Guid.NewGuid()
        });

        Func<Task> act = () => new PreviewComboHandler(trickRepo.Object, prefRepo.Object, CreateHttp(_userId))
            .Handle(new PreviewComboCommand(prefId, null), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>()
            .WithMessage("Preference not found.");
    }

    [Fact]
    public async Task PreviewCombo_WithCustomOverrides_ReturnsPreview()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var prefRepo = new Mock<IUserPreferenceRepository>();
        var tricks = TrickFaker.CreateMany(5, crossOver: false);
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync(tricks);

        var result = await new PreviewComboHandler(trickRepo.Object, prefRepo.Object, CreateHttp(_userId))
            .Handle(new PreviewComboCommand(null, new GenerateComboOverrides { ComboLength = 3, NoTouchPercentage = 0 }), CancellationToken.None);

        result.Tricks.Should().HaveCount(3);
        result.Tricks.Select(t => t.Position).Should().Equal([1, 2, 3]);
    }

    [Fact]
    public async Task PreviewCombo_NoTricksMatchFilter_ThrowsInvalidOperationException()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var prefRepo = new Mock<IUserPreferenceRepository>();
        // All tricks have difficulty 5; filter requires difficulty <= 1
        var tricks = TrickFaker.CreateMany(3).Select(t => { t.Difficulty = 5; return t; }).ToList();
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync(tricks);

        Func<Task> act = () => new PreviewComboHandler(trickRepo.Object, prefRepo.Object, CreateHttp(_userId))
            .Handle(new PreviewComboCommand(null, new GenerateComboOverrides { MaxDifficulty = 1 }), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("No tricks match your preferences.");
    }

    [Fact]
    public async Task BuildCombo_NoTouchOnCrossOverTrick_IsPreserved()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        var crossOverTrick = TrickFaker.Create(crossOver: true, difficulty: 3);
        Combo? savedCombo = null;

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([crossOverTrick]);
        comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>()))
            .Callback<Combo, CancellationToken>((c, _) => savedCombo = c)
            .Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "me" });

        await new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object)
            .Handle(new BuildComboCommand([new BuildComboTrickItem(crossOverTrick.Id, null, 1, true, true)], false), CancellationToken.None);

        savedCombo!.ComboTricks.Single().NoTouch.Should().BeTrue();
    }

    [Fact]
    public async Task BuildCombo_WhitespaceOnlyName_StoredAsNull()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        var trick = TrickFaker.Create(crossOver: false);
        Combo? savedCombo = null;

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([trick]);
        comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>()))
            .Callback<Combo, CancellationToken>((c, _) => savedCombo = c)
            .Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "me" });

        await new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object)
            .Handle(new BuildComboCommand([new BuildComboTrickItem(trick.Id, null, 1, true, false)], false, "   "), CancellationToken.None);

        savedCombo!.Name.Should().BeNull();
    }

    [Fact]
    public async Task UpdateVisibility_ComboNotFound_ThrowsKeyNotFoundException()
    {
        var repo = new Mock<IComboRepository>();
        repo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);

        Func<Task> act = () => new UpdateVisibilityHandler(repo.Object, CreateHttp(_userId))
            .Handle(new UpdateVisibilityCommand(_comboId, _userId, true), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>().WithMessage("Combo not found.");
    }

    [Fact]
    public async Task UpdateVisibility_AdminMakingComboPublic_SetsPublicDirectly()
    {
        var repo = new Mock<IComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = Guid.NewGuid(), Visibility = ComboVisibility.PendingReview };
        repo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        repo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new UpdateVisibilityHandler(repo.Object, CreateHttp(_userId, isAdmin: true))
            .Handle(new UpdateVisibilityCommand(_comboId, _userId, true), CancellationToken.None);

        combo.Visibility.Should().Be(ComboVisibility.Public);
    }

    [Fact]
    public async Task UpdateVisibility_AdminCanMakePublicComboPrivate()
    {
        var repo = new Mock<IComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = Guid.NewGuid(), Visibility = ComboVisibility.Public };
        repo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        repo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new UpdateVisibilityHandler(repo.Object, CreateHttp(_userId, isAdmin: true))
            .Handle(new UpdateVisibilityCommand(_comboId, _userId, false), CancellationToken.None);

        combo.Visibility.Should().Be(ComboVisibility.Private);
    }

    // --- Sub-combo slot tests ---

    private static Combo CreateReusableSubCombo(Guid id, string name, List<Trick> tricks)
    {
        var combo = new Combo
        {
            Id = id,
            Name = name,
            IsReusable = true,
            OwnerId = Guid.NewGuid(),
            Visibility = ComboVisibility.Public,
            CreatedAt = DateTime.UtcNow
        };
        combo.ComboTricks = tricks.Select((t, i) => new ComboTrick
        {
            Id = Guid.NewGuid(),
            ComboId = combo.Id,
            TrickId = t.Id,
            Trick = t,
            Position = i + 1
        }).ToList();
        return combo;
    }

    [Fact]
    public async Task BuildCombo_WithTricksOnly_Works()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        var trick = TrickFaker.Create(name: "ATW", crossOver: false, difficulty: 3);
        Combo? savedCombo = null;

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([trick]);
        comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>()))
            .Callback<Combo, CancellationToken>((c, _) => savedCombo = c)
            .Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "u" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        var result = await handler.Handle(
            new BuildComboCommand([new BuildComboTrickItem(trick.Id, null, 1, false, false)]),
            CancellationToken.None);

        savedCombo.Should().NotBeNull();
        savedCombo!.TrickCount.Should().Be(1);
        result.Tricks.Should().HaveCount(1);
        result.Tricks[0].Type.Should().Be("trick");
        result.Tricks[0].TrickId.Should().Be(trick.Id);
    }

    [Fact]
    public async Task BuildCombo_WithSubComboSlot_Works()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();

        var directTrick = TrickFaker.Create(name: "ATW", crossOver: false, difficulty: 4);
        var subTrick1 = TrickFaker.Create(name: "XO", crossOver: true, difficulty: 2);
        var subTrick2 = TrickFaker.Create(name: "CRO", crossOver: true, difficulty: 2);
        var subComboId = Guid.NewGuid();
        var subCombo = CreateReusableSubCombo(subComboId, "Foundation", [subTrick1, subTrick2]);

        Combo? savedCombo = null;
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([directTrick]);
        comboRepo.Setup(r => r.GetByIdAsync(subComboId, It.IsAny<CancellationToken>())).ReturnsAsync(subCombo);
        comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>()))
            .Callback<Combo, CancellationToken>((c, _) => savedCombo = c)
            .Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "u" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        var result = await handler.Handle(new BuildComboCommand([
            new BuildComboTrickItem(directTrick.Id, null, 1, false, false),
            new BuildComboTrickItem(null, subComboId, 2, false, false)
        ]), CancellationToken.None);

        // TrickCount should expand sub-combo (1 direct + 2 sub-combo tricks)
        savedCombo!.TrickCount.Should().Be(3);

        // DisplayText should embed the sub-combo name + abbreviations
        result.DisplayText.Should().Contain($"[Foundation: {subTrick1.Abbreviation} {subTrick2.Abbreviation}]");

        // Response should have a "combo" slot
        var comboSlot = result.Tricks.Single(t => t.Type == "combo");
        comboSlot.SubComboId.Should().Be(subComboId);
        comboSlot.SubComboName.Should().Be("Foundation");
        comboSlot.SubComboTricks.Should().HaveCount(2);
    }

    [Fact]
    public async Task BuildCombo_WithSubComboSlot_CalculatesCorrectTotalDifficulty()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();

        var directTrick = TrickFaker.Create(crossOver: false, difficulty: 6);
        var subTrick1 = TrickFaker.Create(crossOver: false, difficulty: 2);
        var subTrick2 = TrickFaker.Create(crossOver: false, difficulty: 4);
        var subComboId = Guid.NewGuid();
        var subCombo = CreateReusableSubCombo(subComboId, "Sub", [subTrick1, subTrick2]);

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([directTrick]);
        comboRepo.Setup(r => r.GetByIdAsync(subComboId, It.IsAny<CancellationToken>())).ReturnsAsync(subCombo);
        comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "u" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        var result = await handler.Handle(new BuildComboCommand([
            new BuildComboTrickItem(directTrick.Id, null, 1, false, false),
            new BuildComboTrickItem(null, subComboId, 2, false, false)
        ]), CancellationToken.None);

        // Sum of difficulties 6 + 2 + 4 = 12
        result.TotalDifficulty.Should().Be(12.0);
    }

    [Fact]
    public async Task BuildCombo_Throws_WhenSubComboNotReusable()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();

        var subComboId = Guid.NewGuid();
        var notReusable = new Combo { Id = subComboId, Name = "Nope", IsReusable = false };

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        comboRepo.Setup(r => r.GetByIdAsync(subComboId, It.IsAny<CancellationToken>())).ReturnsAsync(notReusable);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "u" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        Func<Task> act = () => handler.Handle(
            new BuildComboCommand([new BuildComboTrickItem(null, subComboId, 1, false, false)]),
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage($"*{subComboId}*is not reusable*");
    }

    [Fact]
    public async Task BuildCombo_Throws_WhenSubComboHasNestedSubCombo()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();

        var subComboId = Guid.NewGuid();
        var nested = new Combo
        {
            Id = subComboId,
            Name = "Nested",
            IsReusable = true,
            ComboTricks = [new ComboTrick { Id = Guid.NewGuid(), SubComboId = Guid.NewGuid() }]
        };

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        comboRepo.Setup(r => r.GetByIdAsync(subComboId, It.IsAny<CancellationToken>())).ReturnsAsync(nested);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "u" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        Func<Task> act = () => handler.Handle(
            new BuildComboCommand([new BuildComboTrickItem(null, subComboId, 1, false, false)]),
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*nested sub-combos*");
    }

    [Fact]
    public async Task BuildCombo_Throws_WhenSubComboNotFound()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();

        var missingId = Guid.NewGuid();
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        comboRepo.Setup(r => r.GetByIdAsync(missingId, It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "u" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        Func<Task> act = () => handler.Handle(
            new BuildComboCommand([new BuildComboTrickItem(null, missingId, 1, false, false)]),
            CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>()
            .WithMessage($"*{missingId}*not found*");
    }

    [Fact]
    public async Task BuildCombo_Throws_WhenMixedSlotHasBothIds()
    {
        var trickRepo = new Mock<ITrickRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();

        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "u" });

        var handler = new BuildComboHandler(trickRepo.Object, comboRepo.Object, CreateHttp(_userId), userManager.Object);
        // Both TrickId and SubComboId set — violates XOR
        Func<Task> act = () => handler.Handle(
            new BuildComboCommand([new BuildComboTrickItem(Guid.NewGuid(), Guid.NewGuid(), 1, false, false)]),
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*exactly one of TrickId or SubComboId*");
    }
}
