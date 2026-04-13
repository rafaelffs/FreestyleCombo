using FluentAssertions;
using FreestyleCombo.API.Features.Combos.ApproveComboVisibility;
using FreestyleCombo.API.Features.Combos.RejectComboVisibility;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class ComboVisibilityHandlerTests
{
    private readonly Mock<IComboRepository> _comboRepo = new();
    private readonly Guid _comboId = Guid.NewGuid();

    private Combo PendingCombo() => new()
    {
        Id = _comboId,
        OwnerId = Guid.NewGuid(),
        Visibility = ComboVisibility.PendingReview,
        CreatedAt = DateTime.UtcNow
    };

    [Fact]
    public async Task Approve_PendingCombo_SetsVisibilityToPublic()
    {
        var combo = PendingCombo();
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        _comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new ApproveComboVisibilityHandler(_comboRepo.Object)
            .Handle(new ApproveComboVisibilityCommand(_comboId), CancellationToken.None);

        combo.Visibility.Should().Be(ComboVisibility.Public);
        _comboRepo.Verify(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Approve_ComboNotFound_ThrowsKeyNotFoundException()
    {
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);

        Func<Task> act = () => new ApproveComboVisibilityHandler(_comboRepo.Object)
            .Handle(new ApproveComboVisibilityCommand(_comboId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task Approve_ComboNotPendingReview_ThrowsInvalidOperationException()
    {
        var combo = PendingCombo();
        combo.Visibility = ComboVisibility.Public;
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        Func<Task> act = () => new ApproveComboVisibilityHandler(_comboRepo.Object)
            .Handle(new ApproveComboVisibilityCommand(_comboId), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Only combos pending review can be approved.");
    }

    [Fact]
    public async Task Reject_PendingCombo_SetsVisibilityToPrivate()
    {
        var combo = PendingCombo();
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        _comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new RejectComboVisibilityHandler(_comboRepo.Object)
            .Handle(new RejectComboVisibilityCommand(_comboId), CancellationToken.None);

        combo.Visibility.Should().Be(ComboVisibility.Private);
        _comboRepo.Verify(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Reject_ComboNotFound_ThrowsKeyNotFoundException()
    {
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);

        Func<Task> act = () => new RejectComboVisibilityHandler(_comboRepo.Object)
            .Handle(new RejectComboVisibilityCommand(_comboId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task Reject_ComboNotPendingReview_ThrowsInvalidOperationException()
    {
        var combo = PendingCombo();
        combo.Visibility = ComboVisibility.Private;
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        Func<Task> act = () => new RejectComboVisibilityHandler(_comboRepo.Object)
            .Handle(new RejectComboVisibilityCommand(_comboId), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Only combos pending review can be rejected.");
    }
}
