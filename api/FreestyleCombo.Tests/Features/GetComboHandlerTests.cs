using FluentAssertions;
using FreestyleCombo.API.Features.Combos.GetCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class GetComboHandlerTests
{
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _otherUserId = Guid.NewGuid();

    private static Combo MakeCombo(Guid ownerId, ComboVisibility visibility)
    {
        var trick = TrickFaker.Create(crossOver: true, difficulty: 4);
        return new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = ownerId,
            Owner = new AppUser { Id = ownerId, UserName = "owner" },
            Visibility = visibility,
            AverageDifficulty = 4,
            TrickCount = 1,
            ComboTricks =
            [
                new ComboTrick { Id = Guid.NewGuid(), TrickId = trick.Id, Trick = trick, Position = 1, StrongFoot = true }
            ],
            Ratings = []
        };
    }

    [Fact]
    public async Task GetCombo_NotFound_ThrowsKeyNotFoundException()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        repo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);

        Func<Task> act = () => new GetComboHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetComboQuery(Guid.NewGuid(), _userId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>().WithMessage("Combo not found.");
    }

    [Fact]
    public async Task GetCombo_PrivateComboForOwner_ReturnsDto()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var combo = MakeCombo(_userId, ComboVisibility.Private);

        repo.Setup(r => r.GetByIdAsync(combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        favRepo.Setup(r => r.ExistsAsync(_userId, combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        completionRepo.Setup(r => r.ExistsAsync(_userId, combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        completionRepo.Setup(r => r.GetCompletionCountsAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, int>());

        var result = await new GetComboHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetComboQuery(combo.Id, _userId), CancellationToken.None);

        result.Id.Should().Be(combo.Id);
        result.Visibility.Should().Be("Private");
    }

    [Fact]
    public async Task GetCombo_PendingComboForNonOwner_ThrowsUnauthorizedAccessException()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var combo = MakeCombo(_otherUserId, ComboVisibility.PendingReview);
        repo.Setup(r => r.GetByIdAsync(combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        Func<Task> act = () => new GetComboHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetComboQuery(combo.Id, _userId), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>().WithMessage("Access denied.");
    }

    [Fact]
    public async Task GetCombo_PublicComboWithoutUser_SkipsFavAndCompletionLookup()
    {
        var repo = new Mock<IComboRepository>();
        var favRepo = new Mock<IUserFavouriteRepository>();
        var completionRepo = new Mock<IUserComboCompletionRepository>();
        var combo = MakeCombo(_otherUserId, ComboVisibility.Public);

        repo.Setup(r => r.GetByIdAsync(combo.Id, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        completionRepo.Setup(r => r.GetCompletionCountsAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, int>());

        var result = await new GetComboHandler(repo.Object, favRepo.Object, completionRepo.Object)
            .Handle(new GetComboQuery(combo.Id, null), CancellationToken.None);

        result.IsFavourited.Should().BeFalse();
        result.IsCompleted.Should().BeFalse();
        favRepo.Verify(r => r.ExistsAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
        completionRepo.Verify(r => r.ExistsAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}
