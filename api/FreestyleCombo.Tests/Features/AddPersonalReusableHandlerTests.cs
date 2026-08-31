using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.API.Features.Combos.AddPersonalReusable;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Microsoft.AspNetCore.Http;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class AddPersonalReusableHandlerTests
{
    private readonly Guid _comboId = Guid.NewGuid();
    private readonly Guid _ownerId = Guid.NewGuid();

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

    [Theory]
    [InlineData(ComboVisibility.Private)]
    [InlineData(ComboVisibility.PendingReview)]
    [InlineData(ComboVisibility.Public)]
    public async Task Owner_CanAddTheirOwnCombo_AtAnyVisibility(ComboVisibility visibility)
    {
        var comboRepo = new Mock<IComboRepository>();
        var personalReusableRepo = new Mock<IUserPersonalReusableComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _ownerId, Visibility = visibility };

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        var handler = new AddPersonalReusableHandler(comboRepo.Object, personalReusableRepo.Object, CreateHttp(_ownerId));
        await handler.Handle(new AddPersonalReusableCommand(_comboId, _ownerId), CancellationToken.None);

        personalReusableRepo.Verify(r => r.AddAsync(_ownerId, _comboId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task NonOwner_CanAdd_APublicCombo()
    {
        var comboRepo = new Mock<IComboRepository>();
        var personalReusableRepo = new Mock<IUserPersonalReusableComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _ownerId, Visibility = ComboVisibility.Public };
        var otherUserId = Guid.NewGuid();

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        var handler = new AddPersonalReusableHandler(comboRepo.Object, personalReusableRepo.Object, CreateHttp(otherUserId));
        await handler.Handle(new AddPersonalReusableCommand(_comboId, otherUserId), CancellationToken.None);

        personalReusableRepo.Verify(r => r.AddAsync(otherUserId, _comboId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData(ComboVisibility.Private)]
    [InlineData(ComboVisibility.PendingReview)]
    public async Task NonOwner_CannotAdd_ANonPublicCombo(ComboVisibility visibility)
    {
        var comboRepo = new Mock<IComboRepository>();
        var personalReusableRepo = new Mock<IUserPersonalReusableComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _ownerId, Visibility = visibility };
        var otherUserId = Guid.NewGuid();

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        var handler = new AddPersonalReusableHandler(comboRepo.Object, personalReusableRepo.Object, CreateHttp(otherUserId));
        Func<Task> act = () => handler.Handle(new AddPersonalReusableCommand(_comboId, otherUserId), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        personalReusableRepo.Verify(r => r.AddAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Theory]
    [InlineData(ComboVisibility.Private)]
    [InlineData(ComboVisibility.PendingReview)]
    public async Task Admin_CanAdd_AnyoneElsesNonPublicCombo(ComboVisibility visibility)
    {
        var comboRepo = new Mock<IComboRepository>();
        var personalReusableRepo = new Mock<IUserPersonalReusableComboRepository>();
        var combo = new Combo { Id = _comboId, OwnerId = _ownerId, Visibility = visibility };
        var adminId = Guid.NewGuid();

        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(combo);

        var handler = new AddPersonalReusableHandler(comboRepo.Object, personalReusableRepo.Object, CreateHttp(adminId, isAdmin: true));
        Func<Task> act = () => handler.Handle(new AddPersonalReusableCommand(_comboId, adminId), CancellationToken.None);

        await act.Should().NotThrowAsync();
        personalReusableRepo.Verify(r => r.AddAsync(adminId, _comboId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Throws_WhenComboNotFound()
    {
        var comboRepo = new Mock<IComboRepository>();
        var personalReusableRepo = new Mock<IUserPersonalReusableComboRepository>();
        comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);

        var handler = new AddPersonalReusableHandler(comboRepo.Object, personalReusableRepo.Object, CreateHttp(_ownerId));
        Func<Task> act = () => handler.Handle(new AddPersonalReusableCommand(_comboId, _ownerId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>().WithMessage("Combo not found.");
    }
}
