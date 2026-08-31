using FluentAssertions;
using FreestyleCombo.API.Features.Combos.SetPersonalReusable;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class SetPersonalReusableHandlerTests
{
    private readonly Guid _comboId = Guid.NewGuid();
    private readonly Guid _ownerId = Guid.NewGuid();

    [Theory]
    [InlineData(ComboVisibility.Private)]
    [InlineData(ComboVisibility.PendingReview)]
    [InlineData(ComboVisibility.Public)]
    public async Task SetPersonalReusable_OwnerCanSetTrue_AtAnyVisibility(ComboVisibility visibility)
    {
        var comboRepo = new Mock<IComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _ownerId, Visibility = visibility, ComboTricks = [] };

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        var handler = new SetPersonalReusableHandler(comboRepo.Object);
        await handler.Handle(new SetPersonalReusableCommand(_comboId, _ownerId, true), CancellationToken.None);

        combo.IsPersonalReusable.Should().BeTrue();
        comboRepo.Verify(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SetPersonalReusable_OwnerCanUnset_WithNoReferenceGuard()
    {
        var comboRepo = new Mock<IComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _ownerId, Visibility = ComboVisibility.Private, IsPersonalReusable = true, ComboTricks = [] };

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        var handler = new SetPersonalReusableHandler(comboRepo.Object);
        await handler.Handle(new SetPersonalReusableCommand(_comboId, _ownerId, false), CancellationToken.None);

        combo.IsPersonalReusable.Should().BeFalse();
    }

    [Fact]
    public async Task SetPersonalReusable_Throws_WhenCallerIsNotOwner()
    {
        var comboRepo = new Mock<IComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _ownerId, Visibility = ComboVisibility.Private, ComboTricks = [] };
        var otherUserId = Guid.NewGuid();

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        var handler = new SetPersonalReusableHandler(comboRepo.Object);
        Func<Task> act = () => handler.Handle(new SetPersonalReusableCommand(_comboId, otherUserId, true), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        comboRepo.Verify(r => r.UpdateAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SetPersonalReusable_Throws_WhenComboNotFound()
    {
        var comboRepo = new Mock<IComboRepository>();
        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);

        var handler = new SetPersonalReusableHandler(comboRepo.Object);
        Func<Task> act = () => handler.Handle(new SetPersonalReusableCommand(_comboId, _ownerId, true), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>().WithMessage("Combo not found.");
    }
}
