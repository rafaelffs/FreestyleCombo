using FluentAssertions;
using FreestyleCombo.API.Features.Preferences.CreatePreference;
using FreestyleCombo.API.Features.Preferences.DeletePreference;
using FreestyleCombo.API.Features.Preferences.UpdatePreferences;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class PreferenceHandlerTests
{
    private readonly Mock<IUserPreferenceRepository> _repo = new();
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _otherId = Guid.NewGuid();
    private readonly Guid _prefId = Guid.NewGuid();

    private CreatePreferenceCommand DefaultCreateCommand() => new(
        _userId, "My Pref", 6, 5, 50, 20, 3, true, false, [1m, 2m]);

    private UpdatePreferencesCommand DefaultUpdateCommand(Guid callerId) => new(
        _prefId, callerId, "Updated", 7, 6, 60, 30, 4, false, true, [3m]);

    private UserPreference StoredPref() => new()
    {
        Id = _prefId,
        UserId = _userId,
        Name = "My Pref",
        MaxDifficulty = 6,
        ComboLength = 5,
        StrongFootPercentage = 50,
        NoTouchPercentage = 20,
        MaxConsecutiveNoTouch = 3,
        IncludeCrossOver = true,
        IncludeKnee = false,
        AllowedRevolutions = [1m, 2m]
    };

    [Fact]
    public async Task CreatePreference_ReturnsPreferenceDtoWithCorrectFields()
    {
        _repo.Setup(r => r.AddAsync(It.IsAny<UserPreference>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        var result = await new CreatePreferenceHandler(_repo.Object)
            .Handle(DefaultCreateCommand(), CancellationToken.None);

        result.Should().NotBeNull();
        result.Name.Should().Be("My Pref");
        result.MaxDifficulty.Should().Be(6);
        result.ComboLength.Should().Be(5);
        result.AllowedRevolutions.Should().BeEquivalentTo(new List<decimal> { 1m, 2m });
        result.Id.Should().NotBeEmpty();
    }

    [Fact]
    public async Task UpdatePreferences_Owner_UpdatesAndReturnsDto()
    {
        var pref = StoredPref();
        _repo.Setup(r => r.GetByIdAsync(_prefId, It.IsAny<CancellationToken>())).ReturnsAsync(pref);
        _repo.Setup(r => r.UpdateAsync(pref, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        var result = await new UpdatePreferencesHandler(_repo.Object)
            .Handle(DefaultUpdateCommand(_userId), CancellationToken.None);

        result.Name.Should().Be("Updated");
        result.MaxDifficulty.Should().Be(7);
        result.AllowedRevolutions.Should().BeEquivalentTo(new List<decimal> { 3m });
        _repo.Verify(r => r.UpdateAsync(pref, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UpdatePreferences_NotFound_ThrowsKeyNotFoundException()
    {
        _repo.Setup(r => r.GetByIdAsync(_prefId, It.IsAny<CancellationToken>())).ReturnsAsync((UserPreference?)null);

        Func<Task> act = () => new UpdatePreferencesHandler(_repo.Object)
            .Handle(DefaultUpdateCommand(_userId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task UpdatePreferences_NotOwner_ThrowsUnauthorizedAccessException()
    {
        _repo.Setup(r => r.GetByIdAsync(_prefId, It.IsAny<CancellationToken>())).ReturnsAsync(StoredPref());

        Func<Task> act = () => new UpdatePreferencesHandler(_repo.Object)
            .Handle(DefaultUpdateCommand(_otherId), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task DeletePreference_Owner_CallsDeleteAsync()
    {
        var pref = StoredPref();
        _repo.Setup(r => r.GetByIdAsync(_prefId, It.IsAny<CancellationToken>())).ReturnsAsync(pref);
        _repo.Setup(r => r.DeleteAsync(pref, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new DeletePreferenceHandler(_repo.Object)
            .Handle(new DeletePreferenceCommand(_prefId, _userId), CancellationToken.None);

        _repo.Verify(r => r.DeleteAsync(pref, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task DeletePreference_NotFound_ThrowsKeyNotFoundException()
    {
        _repo.Setup(r => r.GetByIdAsync(_prefId, It.IsAny<CancellationToken>())).ReturnsAsync((UserPreference?)null);

        Func<Task> act = () => new DeletePreferenceHandler(_repo.Object)
            .Handle(new DeletePreferenceCommand(_prefId, _userId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task DeletePreference_NotOwner_ThrowsUnauthorizedAccessException()
    {
        _repo.Setup(r => r.GetByIdAsync(_prefId, It.IsAny<CancellationToken>())).ReturnsAsync(StoredPref());

        Func<Task> act = () => new DeletePreferenceHandler(_repo.Object)
            .Handle(new DeletePreferenceCommand(_prefId, _otherId), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }
}
