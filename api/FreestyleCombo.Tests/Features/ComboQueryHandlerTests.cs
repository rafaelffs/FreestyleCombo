using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.API.Features.Combos.BuildCombo;
using FreestyleCombo.API.Features.Combos.GetCombo;
using FreestyleCombo.API.Features.Combos.GetFavouritedCombos;
using FreestyleCombo.API.Features.Combos.GetMyCombos;
using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using FreestyleCombo.API.Features.Combos.UpdateCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class ComboQueryHandlerTests
{
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _otherUserId = Guid.NewGuid();

    private static Mock<UserManager<AppUser>> CreateUserManagerMock()
    {
        return new Mock<UserManager<AppUser>>(
            Mock.Of<IUserStore<AppUser>>(),
            null!, null!, null!, null!, null!, null!, null!, null!);
    }

    private IHttpContextAccessor CreateHttp(Guid userId, bool isAdmin = false)
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

    private static Combo CreateCombo(Guid comboId, Guid ownerId, string ownerName, ComboVisibility visibility, DateTime createdAt)
    {
        var trick = TrickFaker.Create(name: "ATW", crossOver: true, revolution: 1.0m, difficulty: 3, commonLevel: 4);
        return new Combo
        {
            Id = comboId,
            OwnerId = ownerId,
            Owner = new AppUser { Id = ownerId, UserName = ownerName, Email = ownerName + "@example.com" },
            Name = "Combo",
            AverageDifficulty = 3.5,
            TrickCount = 1,
            Visibility = visibility,
            CreatedAt = createdAt,
            AiDescription = "desc",
            ComboTricks =
            [
                new ComboTrick
                {
                    Id = Guid.NewGuid(),
                    ComboId = comboId,
                    TrickId = trick.Id,
                    Trick = trick,
                    Position = 1,
                    StrongFoot = true,
                    NoTouch = true
                }
            ],
            Ratings =
            [
                new ComboRating { Score = 4 },
                new ComboRating { Score = 5 }
            ]
        };
    }

    [Fact]
    public async Task GetPublicCombos_ReturnsPagedDtosWithFlags()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var combo = CreateCombo(Guid.NewGuid(), _otherUserId, "owner", ComboVisibility.Public, DateTime.UtcNow);

        repo.Setup(r => r.GetPublicAsync(1, 10, "latest", 5, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync((new List<Combo> { combo }, 1));
        favRepo.Setup(r => r.GetFavouriteComboIdsAsync(_userId, It.IsAny<CancellationToken>())).ReturnsAsync([combo.Id]);
        completionRepo.Setup(r => r.GetCompletedComboIdsAsync(_userId, It.IsAny<CancellationToken>())).ReturnsAsync([combo.Id]);
        completionRepo.Setup(r => r.GetCompletionCountsAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, int> { [combo.Id] = 7 });

        var result = await new GetPublicCombosHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetPublicCombosQuery(1, 10, "latest", 5, _userId), CancellationToken.None);

        result.TotalCount.Should().Be(1);
        result.Items.Should().HaveCount(1);
        result.Items[0].IsFavourited.Should().BeTrue();
        result.Items[0].IsCompleted.Should().BeTrue();
        result.Items[0].CompletionCount.Should().Be(7);
        result.Items[0].DisplayText.Should().Contain("(nt)");
        result.Items[0].AverageRating.Should().Be(4.5);
    }

    [Fact]
    public async Task GetPublicCombos_WithoutRequestingUser_SetsFalseFlags()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var combo = CreateCombo(Guid.NewGuid(), _otherUserId, "owner", ComboVisibility.Public, DateTime.UtcNow);

        repo.Setup(r => r.GetPublicAsync(1, 10, null, null, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync((new List<Combo> { combo }, 1));
        completionRepo.Setup(r => r.GetCompletionCountsAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, int>());

        var result = await new GetPublicCombosHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetPublicCombosQuery(1, 10, null, null, null), CancellationToken.None);

        result.Items[0].IsFavourited.Should().BeFalse();
        result.Items[0].IsCompleted.Should().BeFalse();
    }

    [Fact]
    public async Task GetMyCombos_ReturnsPaginatedResultsSortedByCreatedAtDesc()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var older = CreateCombo(Guid.NewGuid(), _userId, "me", ComboVisibility.Private, DateTime.UtcNow.AddDays(-1));
        var newer = CreateCombo(Guid.NewGuid(), _userId, "me", ComboVisibility.PendingReview, DateTime.UtcNow);

        repo.Setup(r => r.GetAllByOwnerAsync(_userId, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync([older, newer]);
        favRepo.Setup(r => r.GetFavouriteComboIdsAsync(_userId, It.IsAny<CancellationToken>())).ReturnsAsync([newer.Id]);
        completionRepo.Setup(r => r.GetCompletedComboIdsAsync(_userId, It.IsAny<CancellationToken>())).ReturnsAsync([older.Id]);
        completionRepo.Setup(r => r.GetCompletionCountsAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, int> { [older.Id] = 1, [newer.Id] = 2 });

        var result = await new GetMyCombosHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetMyCombosQuery(_userId, 1, 10, null), CancellationToken.None);

        result.Items.Select(i => i.Id).Should().Equal([newer.Id, older.Id]);
        result.Items[0].IsFavourited.Should().BeTrue();
        result.Items[1].IsCompleted.Should().BeTrue();
    }

    [Fact]
    public async Task GetFavouritedCombos_ReturnsMappedDtos()
    {
        var repo = new Mock<IComboRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var combo = CreateCombo(Guid.NewGuid(), _otherUserId, "owner", ComboVisibility.Public, DateTime.UtcNow);

        repo.Setup(r => r.GetFavouritedByUserAsync(_userId, It.IsAny<CancellationToken>())).ReturnsAsync([combo]);
        completionRepo.Setup(r => r.GetCompletedComboIdsAsync(_userId, It.IsAny<CancellationToken>())).ReturnsAsync([combo.Id]);
        completionRepo.Setup(r => r.GetCompletionCountsAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, int> { [combo.Id] = 5 });

        var result = await new GetFavouritedCombosHandler(repo.Object, completionRepo.Object)
            .Handle(new GetFavouritedCombosQuery(_userId), CancellationToken.None);

        result.Should().HaveCount(1);
        result[0].IsFavourited.Should().BeTrue();
        result[0].IsCompleted.Should().BeTrue();
        result[0].CompletionCount.Should().Be(5);
    }

    [Fact]
    public async Task GetCombo_PublicCombo_ReturnsDetailedDtoWithFlags()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var combo = CreateCombo(Guid.NewGuid(), _otherUserId, "owner", ComboVisibility.Public, DateTime.UtcNow);

        repo.Setup(r => r.GetByIdAsync(combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        favRepo.Setup(r => r.ExistsAsync(_userId, combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        completionRepo.Setup(r => r.ExistsAsync(_userId, combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        completionRepo.Setup(r => r.GetCompletionCountsAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, int> { [combo.Id] = 4 });

        var result = await new GetComboHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetComboQuery(combo.Id, _userId), CancellationToken.None);

        result.Id.Should().Be(combo.Id);
        result.IsFavourited.Should().BeTrue();
        result.IsCompleted.Should().BeTrue();
        result.CompletionCount.Should().Be(4);
        result.AverageRating.Should().Be(4.5);
    }

    [Fact]
    public async Task GetCombo_PrivateComboForNonOwner_ThrowsUnauthorizedAccessException()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var combo = CreateCombo(Guid.NewGuid(), _otherUserId, "owner", ComboVisibility.Private, DateTime.UtcNow);
        repo.Setup(r => r.GetByIdAsync(combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        Func<Task> act = () => new GetComboHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetComboQuery(combo.Id, _userId), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("Access denied.");
    }

    [Fact]
    public async Task UpdateCombo_OwnerReplacingTricks_UpdatesComboAndResetsPublicToPendingReview()
    {
        var comboRepo = new Mock<IComboRepository>();
        var trickRepo = new Mock<ITrickRepository>();
        var userManager = CreateUserManagerMock();
        var combo = CreateCombo(Guid.NewGuid(), _userId, "me", ComboVisibility.Public, DateTime.UtcNow.AddDays(-1));
        var nonCrossOver = TrickFaker.Create(name: "ATW", crossOver: false, revolution: 1.0m, difficulty: 2, commonLevel: 4);
        var crossOver = TrickFaker.Create(name: "MATW", crossOver: true, revolution: 2.0m, difficulty: 4, commonLevel: 4);

        comboRepo.Setup(r => r.GetByIdAsync(combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        comboRepo.Setup(r => r.ReplaceComboTricksAsync(combo.Id, It.IsAny<IEnumerable<ComboTrick>>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([nonCrossOver, crossOver]);
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(new AppUser { Id = _userId, UserName = "me" });

        var handler = new UpdateComboHandler(comboRepo.Object, trickRepo.Object, CreateHttp(_userId), userManager.Object);
        var result = await handler.Handle(new UpdateComboCommand(
            combo.Id,
            "  Updated Combo  ",
            [
                new BuildComboTrickItem(nonCrossOver.Id, 2, true, true),
                new BuildComboTrickItem(crossOver.Id, 1, false, true)
            ]), CancellationToken.None);

        combo.Name.Should().Be("Updated Combo");
        combo.Visibility.Should().Be(ComboVisibility.PendingReview);
        combo.TrickCount.Should().Be(2);
        combo.AverageDifficulty.Should().Be(3.0);
        result.DisplayText.Should().Contain(crossOver.Abbreviation + "(nt)");
        result.DisplayText.Should().Contain(nonCrossOver.Abbreviation);
        result.Tricks.Single(t => t.TrickId == nonCrossOver.Id).NoTouch.Should().BeFalse();
        comboRepo.Verify(r => r.ReplaceComboTricksAsync(combo.Id, It.IsAny<IEnumerable<ComboTrick>>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UpdateCombo_NonOwnerNonAdmin_ThrowsUnauthorizedAccessException()
    {
        var comboRepo = new Mock<IComboRepository>();
        var trickRepo = new Mock<ITrickRepository>();
        var userManager = CreateUserManagerMock();
        var combo = CreateCombo(Guid.NewGuid(), _otherUserId, "owner", ComboVisibility.Private, DateTime.UtcNow);
        comboRepo.Setup(r => r.GetByIdAsync(combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        var handler = new UpdateComboHandler(comboRepo.Object, trickRepo.Object, CreateHttp(_userId), userManager.Object);
        Func<Task> act = () => handler.Handle(new UpdateComboCommand(combo.Id, "name", null), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("You do not have permission to edit this combo.");
    }

    [Fact]
    public async Task UpdateCombo_AdminKeepsPublicVisibilityOnNameOnlyEdit()
    {
        var comboRepo = new Mock<IComboRepository>();
        var trickRepo = new Mock<ITrickRepository>();
        var userManager = CreateUserManagerMock();
        var combo = CreateCombo(Guid.NewGuid(), _otherUserId, "owner", ComboVisibility.Public, DateTime.UtcNow);
        comboRepo.Setup(r => r.GetByIdAsync(combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(combo.OwnerId.ToString())).ReturnsAsync(new AppUser { Id = combo.OwnerId, UserName = "owner" });

        var handler = new UpdateComboHandler(comboRepo.Object, trickRepo.Object, CreateHttp(_userId, isAdmin: true), userManager.Object);
        var result = await handler.Handle(new UpdateComboCommand(combo.Id, "  Admin Edit  ", null), CancellationToken.None);

        combo.Visibility.Should().Be(ComboVisibility.Public);
        combo.Name.Should().Be("Admin Edit");
        result.Visibility.Should().Be("Public");
    }
}
