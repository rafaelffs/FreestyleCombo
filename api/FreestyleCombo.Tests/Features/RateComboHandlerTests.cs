using FluentAssertions;
using FreestyleCombo.API.Features.Ratings.RateCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class RateComboHandlerTests
{
    private readonly Mock<IComboRepository> _comboRepo = new();
    private readonly Mock<IComboRatingRepository> _ratingRepo = new();
    private readonly Guid _ownerId = Guid.NewGuid();
    private readonly Guid _raterId = Guid.NewGuid();
    private readonly Guid _comboId = Guid.NewGuid();

    private RateComboHandler CreateHandler() => new(_comboRepo.Object, _ratingRepo.Object);

    private Combo PublicCombo() => new()
    {
        Id = _comboId,
        OwnerId = _ownerId,
        Visibility = ComboVisibility.Public,
        TrickCount = 3,
        AverageDifficulty = 5,
        CreatedAt = DateTime.UtcNow,
        Ratings = []
    };

    [Fact]
    public async Task Handle_ValidRating_ReturnsRatingId()
    {
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(PublicCombo());
        _ratingRepo.Setup(r => r.GetByComboAndUserAsync(_comboId, _raterId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((ComboRating?)null);
        _ratingRepo.Setup(r => r.AddAsync(It.IsAny<ComboRating>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var handler = CreateHandler();
        var result = await handler.Handle(new RateComboCommand(_comboId, _raterId, 4), CancellationToken.None);

        result.Should().NotBeEmpty();
    }

    [Fact]
    public async Task Handle_OwnCombo_ThrowsInvalidOperationException()
    {
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(PublicCombo());

        var handler = CreateHandler();
        Func<Task> act = () => handler.Handle(new RateComboCommand(_comboId, _ownerId, 3), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("You cannot rate your own combo.");
    }

    [Fact]
    public async Task Handle_AlreadyRated_ThrowsInvalidOperationException()
    {
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(PublicCombo());
        _ratingRepo.Setup(r => r.GetByComboAndUserAsync(_comboId, _raterId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ComboRating { Id = Guid.NewGuid(), ComboId = _comboId, RatedByUserId = _raterId, Score = 4, CreatedAt = DateTime.UtcNow });

        var handler = CreateHandler();
        Func<Task> act = () => handler.Handle(new RateComboCommand(_comboId, _raterId, 5), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("You have already rated this combo.");
    }

    [Fact]
    public async Task Handle_ComboNotFound_ThrowsKeyNotFoundException()
    {
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Combo?)null);

        var handler = CreateHandler();
        Func<Task> act = () => handler.Handle(new RateComboCommand(_comboId, _raterId, 3), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task Handle_PrivateCombo_ThrowsUnauthorizedAccessException()
    {
        var privateCombo = PublicCombo();
        privateCombo.Visibility = ComboVisibility.Private;

        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(privateCombo);

        var handler = CreateHandler();
        Func<Task> act = () => handler.Handle(new RateComboCommand(_comboId, _raterId, 3), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }
}
