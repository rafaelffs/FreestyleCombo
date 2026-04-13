using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.API.Features.Combos.DeleteCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Microsoft.AspNetCore.Http;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class DeleteComboHandlerTests
{
    private readonly Mock<IComboRepository> _comboRepo = new();
    private readonly Mock<IHttpContextAccessor> _http = new();
    private readonly Guid _ownerId = Guid.NewGuid();
    private readonly Guid _otherId = Guid.NewGuid();
    private readonly Guid _adminId = Guid.NewGuid();
    private readonly Guid _comboId = Guid.NewGuid();

    private void SetupUser(Guid userId, bool isAdmin = false)
    {
        var claims = new List<Claim> { new(ClaimTypes.NameIdentifier, userId.ToString()) };
        if (isAdmin)
        {
            claims.Add(new Claim(ClaimTypes.Role, "Admin"));
        }

        _http.Setup(x => x.HttpContext).Returns(new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(claims, "test"))
        });
    }

    private Combo OwnerCombo() => new()
    {
        Id = _comboId,
        OwnerId = _ownerId,
        Visibility = ComboVisibility.Private,
        CreatedAt = DateTime.UtcNow
    };

    private DeleteComboHandler CreateHandler() => new(_comboRepo.Object, _http.Object);

    [Fact]
    public async Task Handle_OwnerDeletesOwnCombo_CallsDeleteAsync()
    {
        SetupUser(_ownerId);
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(OwnerCombo());
        _comboRepo.Setup(r => r.DeleteAsync(_comboId, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await CreateHandler().Handle(new DeleteComboCommand(_comboId), CancellationToken.None);

        _comboRepo.Verify(r => r.DeleteAsync(_comboId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_AdminDeletesAnyCombo_CallsDeleteAsync()
    {
        SetupUser(_adminId, isAdmin: true);
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(OwnerCombo());
        _comboRepo.Setup(r => r.DeleteAsync(_comboId, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await CreateHandler().Handle(new DeleteComboCommand(_comboId), CancellationToken.None);

        _comboRepo.Verify(r => r.DeleteAsync(_comboId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_NonOwnerNonAdmin_ThrowsUnauthorizedAccessException()
    {
        SetupUser(_otherId);
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync(OwnerCombo());

        Func<Task> act = () => CreateHandler().Handle(new DeleteComboCommand(_comboId), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Handle_ComboNotFound_ThrowsKeyNotFoundException()
    {
        SetupUser(_ownerId);
        _comboRepo.Setup(r => r.GetByIdAsync(_comboId, It.IsAny<CancellationToken>())).ReturnsAsync((Combo?)null);

        Func<Task> act = () => CreateHandler().Handle(new DeleteComboCommand(_comboId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }
}
