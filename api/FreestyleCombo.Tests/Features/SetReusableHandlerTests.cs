using FluentAssertions;
using FreestyleCombo.API.Features.Combos.SetReusable;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Microsoft.AspNetCore.Identity;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class SetReusableHandlerTests
{
    private readonly Guid _comboId = Guid.NewGuid();
    private readonly Guid _ownerId = Guid.NewGuid();

    private static Mock<UserManager<AppUser>> CreateUserManagerMock()
    {
        return new Mock<UserManager<AppUser>>(
            Mock.Of<IUserStore<AppUser>>(),
            null!, null!, null!, null!, null!, null!, null!, null!);
    }

    private Combo CreatePublicCombo(bool isReusable = false)
    {
        var trick = TrickFaker.Create(name: "ATW", crossOver: false, difficulty: 2, commonLevel: 4);
        return new Combo
        {
            Id = _comboId,
            OwnerId = _ownerId,
            Visibility = ComboVisibility.Public,
            IsReusable = isReusable,
            ComboTricks =
            [
                new ComboTrick
                {
                    Id = Guid.NewGuid(),
                    TrickId = trick.Id,
                    Trick = trick,
                    Position = 1,
                    StrongFoot = true,
                    NoTouch = false
                }
            ]
        };
    }

    [Fact]
    public async Task SetReusable_SetsIsReusableTrue_WhenComboIsPublic()
    {
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        var combo = CreatePublicCombo(isReusable: false);

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_ownerId.ToString()))
            .ReturnsAsync(new AppUser { Id = _ownerId, UserName = "owner" });

        var handler = new SetReusableHandler(comboRepo.Object, userManager.Object);
        var result = await handler.Handle(new SetReusableCommand(_comboId, true), CancellationToken.None);

        combo.IsReusable.Should().BeTrue();
        result.Id.Should().Be(_comboId);
        result.Visibility.Should().Be("Public");
        comboRepo.Verify(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SetReusable_SetsIsReusableFalse_AlwaysAllowed()
    {
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        // Private combo — setting false should still work
        var combo = new Combo
        {
            Id = _comboId,
            OwnerId = _ownerId,
            Visibility = ComboVisibility.Private,
            IsReusable = true,
            ComboTricks = []
        };

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);
        comboRepo.Setup(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        userManager.Setup(m => m.FindByIdAsync(_ownerId.ToString()))
            .ReturnsAsync(new AppUser { Id = _ownerId, UserName = "owner" });

        var handler = new SetReusableHandler(comboRepo.Object, userManager.Object);
        var result = await handler.Handle(new SetReusableCommand(_comboId, false), CancellationToken.None);

        combo.IsReusable.Should().BeFalse();
        result.Id.Should().Be(_comboId);
        comboRepo.Verify(r => r.UpdateAsync(combo, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SetReusable_Throws_WhenComboNotFound()
    {
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);

        var handler = new SetReusableHandler(comboRepo.Object, userManager.Object);
        Func<Task> act = () => handler.Handle(new SetReusableCommand(_comboId, true), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>().WithMessage("Combo not found.");
    }

    [Fact]
    public async Task SetReusable_Throws_WhenSettingTrueOnNonPublicCombo()
    {
        var comboRepo = new Mock<IComboRepository>();
        var userManager = CreateUserManagerMock();
        var combo = new Combo
        {
            Id = _comboId,
            OwnerId = _ownerId,
            Visibility = ComboVisibility.PendingReview,
            ComboTricks = []
        };

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        var handler = new SetReusableHandler(comboRepo.Object, userManager.Object);
        Func<Task> act = () => handler.Handle(new SetReusableCommand(_comboId, true), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Only Public combos can be marked as reusable.");
    }
}
