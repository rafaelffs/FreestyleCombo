using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.API.Features.Auth.Login;
using FreestyleCombo.API.Features.Auth.Register;
using FreestyleCombo.Core.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class AuthHandlerTests
{
    private static Mock<UserManager<AppUser>> CreateUserManagerMock()
    {
        return new Mock<UserManager<AppUser>>(
            Mock.Of<IUserStore<AppUser>>(),
            null!, null!, null!, null!, null!, null!, null!, null!);
    }

    private static IConfiguration CreateJwtConfig() => new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["JwtSettings:Secret"] = "super-secret-key-with-at-least-32-chars",
            ["JwtSettings:Issuer"] = "FreestyleComboAPI",
            ["JwtSettings:Audience"] = "FreestyleComboApp"
        })
        .Build();

    [Fact]
    public async Task Login_ValidCredentials_ReturnsTokenAndUserId()
    {
        var userManager = CreateUserManagerMock();
        var user = new AppUser { Id = Guid.NewGuid(), Email = "user@example.com", UserName = "rafael" };
        userManager.Setup(m => m.FindByEmailAsync("user@example.com")).ReturnsAsync(user);
        userManager.Setup(m => m.CheckPasswordAsync(user, "Password1!")).ReturnsAsync(true);
        userManager.Setup(m => m.GetRolesAsync(user)).ReturnsAsync(["Admin"]);

        var result = await new LoginHandler(userManager.Object, CreateJwtConfig())
            .Handle(new LoginCommand("user@example.com", "Password1!"), CancellationToken.None);

        result.UserId.Should().Be(user.Id);
        result.Token.Should().NotBeNullOrWhiteSpace();

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(result.Token);
        jwt.Claims.Should().Contain(c => c.Type == ClaimTypes.Role && c.Value == "Admin");
    }

    [Fact]
    public async Task Login_FallsBackToUsernameLookup()
    {
        var userManager = CreateUserManagerMock();
        var user = new AppUser { Id = Guid.NewGuid(), Email = "user@example.com", UserName = "rafael" };
        userManager.Setup(m => m.FindByEmailAsync("rafael")).ReturnsAsync((AppUser?)null);
        userManager.Setup(m => m.FindByNameAsync("rafael")).ReturnsAsync(user);
        userManager.Setup(m => m.CheckPasswordAsync(user, "Password1!")).ReturnsAsync(true);
        userManager.Setup(m => m.GetRolesAsync(user)).ReturnsAsync([]);

        var result = await new LoginHandler(userManager.Object, CreateJwtConfig())
            .Handle(new LoginCommand("rafael", "Password1!"), CancellationToken.None);

        result.UserId.Should().Be(user.Id);
    }

    [Fact]
    public async Task Login_UserNotFound_ThrowsUnauthorizedAccessException()
    {
        var userManager = CreateUserManagerMock();
        userManager.Setup(m => m.FindByEmailAsync("missing")).ReturnsAsync((AppUser?)null);
        userManager.Setup(m => m.FindByNameAsync("missing")).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new LoginHandler(userManager.Object, CreateJwtConfig())
            .Handle(new LoginCommand("missing", "Password1!"), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("Invalid credentials.");
    }

    [Fact]
    public async Task Login_InvalidPassword_ThrowsUnauthorizedAccessException()
    {
        var userManager = CreateUserManagerMock();
        var user = new AppUser { Id = Guid.NewGuid(), Email = "user@example.com", UserName = "rafael" };
        userManager.Setup(m => m.FindByEmailAsync("user@example.com")).ReturnsAsync(user);
        userManager.Setup(m => m.CheckPasswordAsync(user, "wrong")).ReturnsAsync(false);

        Func<Task> act = () => new LoginHandler(userManager.Object, CreateJwtConfig())
            .Handle(new LoginCommand("user@example.com", "wrong"), CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("Invalid credentials.");
    }

    [Fact]
    public async Task Register_Success_ReturnsResponse()
    {
        var userManager = CreateUserManagerMock();
        userManager.Setup(m => m.CreateAsync(It.IsAny<AppUser>(), "Password1!"))
            .ReturnsAsync(IdentityResult.Success);

        var result = await new RegisterHandler(userManager.Object)
            .Handle(new RegisterCommand("user@example.com", "rafael", "Password1!"), CancellationToken.None);

        result.Email.Should().Be("user@example.com");
        result.UserName.Should().Be("rafael");
        result.UserId.Should().NotBeEmpty();
    }

    [Fact]
    public async Task Register_Failure_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        userManager.Setup(m => m.CreateAsync(It.IsAny<AppUser>(), "Password1!"))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "Duplicate username" }));

        Func<Task> act = () => new RegisterHandler(userManager.Object)
            .Handle(new RegisterCommand("user@example.com", "rafael", "Password1!"), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Duplicate username");
    }
}
