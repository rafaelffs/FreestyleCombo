using FluentAssertions;
using FreestyleCombo.API.Features.Tricks.CreateTrick;
using FreestyleCombo.API.Features.Tricks.DeleteTrick;
using FreestyleCombo.API.Features.Tricks.UpdateTrick;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class TrickHandlerTests
{
    private readonly Mock<ITrickRepository> _repo = new();

    [Fact]
    public async Task CreateTrick_ReturnsNewGuid()
    {
        _repo.Setup(r => r.AddAsync(It.IsAny<Trick>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        var result = await new CreateTrickHandler(_repo.Object)
            .Handle(new CreateTrickCommand("Around the World", "ATW", false, false, 1.0m, 2, 3), CancellationToken.None);

        result.Should().NotBeEmpty();
        _repo.Verify(r => r.AddAsync(It.IsAny<Trick>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UpdateTrick_ExistingTrick_UpdatesAllFields()
    {
        var trick = TrickFaker.Create(name: "Old Name", difficulty: 1, commonLevel: 2);
        _repo.Setup(r => r.GetByIdAsync(trick.Id, It.IsAny<CancellationToken>())).ReturnsAsync(trick);
        _repo.Setup(r => r.UpdateAsync(trick, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new UpdateTrickHandler(_repo.Object)
            .Handle(new UpdateTrickCommand(trick.Id, "New Name", "NN", true, false, 2.0m, 5, 4), CancellationToken.None);

        trick.Name.Should().Be("New Name");
        trick.Abbreviation.Should().Be("NN");
        trick.CrossOver.Should().BeTrue();
        trick.Revolution.Should().Be(2.0m);
        trick.Difficulty.Should().Be(5);
        trick.CommonLevel.Should().Be(4);
        _repo.Verify(r => r.UpdateAsync(trick, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UpdateTrick_NotFound_ThrowsKeyNotFoundException()
    {
        var id = Guid.NewGuid();
        _repo.Setup(r => r.GetByIdAsync(id, It.IsAny<CancellationToken>())).ReturnsAsync((Trick?)null);

        Func<Task> act = () => new UpdateTrickHandler(_repo.Object)
            .Handle(new UpdateTrickCommand(id, "X", "X", false, false, 1.0m, 1, 1), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task DeleteTrick_CallsRepository()
    {
        var id = Guid.NewGuid();
        _repo.Setup(r => r.DeleteAsync(id, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new DeleteTrickHandler(_repo.Object)
            .Handle(new DeleteTrickCommand(id), CancellationToken.None);

        _repo.Verify(r => r.DeleteAsync(id, It.IsAny<CancellationToken>()), Times.Once);
    }
}
