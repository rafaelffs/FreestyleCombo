using FreestyleCombo.API.Features.Combos.AddFavourite;
using FreestyleCombo.API.Features.Combos.MarkCompleted;
using FreestyleCombo.API.Features.Combos.RemoveFavourite;
using FreestyleCombo.API.Features.Combos.UnmarkCompleted;
using FreestyleCombo.Core.Interfaces;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class FavouriteCompletionHandlerTests
{
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _comboId = Guid.NewGuid();

    [Fact]
    public async Task AddFavourite_CallsRepository()
    {
        var repo = new Mock<IUserFavouriteRepository>();
        repo.Setup(r => r.AddAsync(_userId, _comboId, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new AddFavouriteHandler(repo.Object)
            .Handle(new AddFavouriteCommand(_comboId, _userId), CancellationToken.None);

        repo.Verify(r => r.AddAsync(_userId, _comboId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RemoveFavourite_CallsRepository()
    {
        var repo = new Mock<IUserFavouriteRepository>();
        repo.Setup(r => r.RemoveAsync(_userId, _comboId, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new RemoveFavouriteHandler(repo.Object)
            .Handle(new RemoveFavouriteCommand(_comboId, _userId), CancellationToken.None);

        repo.Verify(r => r.RemoveAsync(_userId, _comboId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task MarkCompleted_CallsRepository()
    {
        var repo = new Mock<IUserComboCompletionRepository>();
        repo.Setup(r => r.AddAsync(_userId, _comboId, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new MarkCompletedHandler(repo.Object)
            .Handle(new MarkCompletedCommand(_comboId, _userId), CancellationToken.None);

        repo.Verify(r => r.AddAsync(_userId, _comboId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UnmarkCompleted_CallsRepository()
    {
        var repo = new Mock<IUserComboCompletionRepository>();
        repo.Setup(r => r.RemoveAsync(_userId, _comboId, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new UnmarkCompletedHandler(repo.Object)
            .Handle(new UnmarkCompletedCommand(_comboId, _userId), CancellationToken.None);

        repo.Verify(r => r.RemoveAsync(_userId, _comboId, It.IsAny<CancellationToken>()), Times.Once);
    }
}
