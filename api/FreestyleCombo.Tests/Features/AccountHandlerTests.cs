using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.API.Features.Account;
using FreestyleCombo.Core.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class AccountHandlerTests
{
    private readonly Guid _userId = Guid.NewGuid();

    private static Mock<UserManager<AppUser>> CreateUserManagerMock()
    {
        return new Mock<UserManager<AppUser>>(
            Mock.Of<IUserStore<AppUser>>(),
            null!, null!, null!, null!, null!, null!, null!, null!);
    }

    private IHttpContextAccessor CreateHttp()
    {
        return new HttpContextAccessor
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(
                [
                    new Claim(ClaimTypes.NameIdentifier, _userId.ToString())
                ], "test"))
            }
        };
    }

    [Fact]
    public async Task GetProfile_ReturnsProfileWithAdminRole()
    {
        var userManager = CreateUserManagerMock();
        var user = new AppUser { Id = _userId, UserName = "rafael", Email = "r@example.com" };
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.GetRolesAsync(user)).ReturnsAsync(["Admin"]);

        var result = await new GetProfileHandler(userManager.Object, CreateHttp())
            .Handle(new GetProfileQuery(), CancellationToken.None);

        result.Id.Should().Be(_userId);
        result.UserName.Should().Be("rafael");
        result.Email.Should().Be("r@example.com");
        result.IsAdmin.Should().BeTrue();
    }

    [Fact]
    public async Task GetProfile_UserNotFound_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new GetProfileHandler(userManager.Object, CreateHttp())
            .Handle(new GetProfileQuery(), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("User not found.");
    }

    [Fact]
    public async Task UpdateProfile_ChangesUsernameAndEmail_ReturnsUpdatedProfile()
    {
        var userManager = CreateUserManagerMock();
        var user = new AppUser { Id = _userId, UserName = "oldname", Email = "old@example.com" };
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.SetUserNameAsync(user, "newname"))
            .Callback<AppUser, string>((target, userName) => target.UserName = userName)
            .ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.GenerateChangeEmailTokenAsync(user, "new@example.com")).ReturnsAsync("token");
        userManager.Setup(m => m.ChangeEmailAsync(user, "new@example.com", "token"))
            .Callback<AppUser, string, string>((target, email, _) => target.Email = email)
            .ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.GetRolesAsync(user)).ReturnsAsync([]);

        var result = await new UpdateProfileHandler(userManager.Object, CreateHttp())
            .Handle(new UpdateProfileCommand("newname", "new@example.com"), CancellationToken.None);

        result.UserName.Should().Be("newname");
        result.Email.Should().Be("new@example.com");
    }

    [Fact]
    public async Task UpdateProfile_UserNotFound_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new UpdateProfileHandler(userManager.Object, CreateHttp())
            .Handle(new UpdateProfileCommand("newname", null), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("User not found.");
    }

    [Fact]
    public async Task UpdateProfile_SetUserNameFailure_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var user = new AppUser { Id = _userId, UserName = "oldname", Email = "old@example.com" };
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.SetUserNameAsync(user, "newname"))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "Duplicate username" }));

        Func<Task> act = () => new UpdateProfileHandler(userManager.Object, CreateHttp())
            .Handle(new UpdateProfileCommand("newname", null), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Duplicate username");
    }

    [Fact]
    public async Task ChangePassword_Success_Completes()
    {
        var userManager = CreateUserManagerMock();
        var user = new AppUser { Id = _userId, UserName = "rafael", Email = "r@example.com" };
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.ChangePasswordAsync(user, "oldpass", "newpass1"))
            .ReturnsAsync(IdentityResult.Success);

        await new ChangePasswordHandler(userManager.Object, CreateHttp())
            .Handle(new ChangePasswordCommand("oldpass", "newpass1"), CancellationToken.None);

        userManager.Verify(m => m.ChangePasswordAsync(user, "oldpass", "newpass1"), Times.Once);
    }

    [Fact]
    public async Task ChangePassword_UserNotFound_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new ChangePasswordHandler(userManager.Object, CreateHttp())
            .Handle(new ChangePasswordCommand("oldpass", "newpass1"), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("User not found.");
    }

    [Fact]
    public async Task ChangePassword_Failure_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var user = new AppUser { Id = _userId, UserName = "rafael", Email = "r@example.com" };
        userManager.Setup(m => m.FindByIdAsync(_userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.ChangePasswordAsync(user, "oldpass", "newpass1"))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "Incorrect password" }));

        Func<Task> act = () => new ChangePasswordHandler(userManager.Object, CreateHttp())
            .Handle(new ChangePasswordCommand("oldpass", "newpass1"), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Incorrect password");
    }

    [Fact]
    public async Task GetPublicProfile_ReturnsPublicProfileDto()
    {
        var userManager = CreateUserManagerMock();
        var targetUserId = Guid.NewGuid();
        var user = new AppUser { Id = targetUserId, UserName = "rafael", Email = "r@example.com" };
        userManager.Setup(m => m.FindByIdAsync(targetUserId.ToString())).ReturnsAsync(user);

        var result = await new GetPublicProfileHandler(userManager.Object)
            .Handle(new GetPublicProfileQuery(targetUserId), CancellationToken.None);

        result.Id.Should().Be(targetUserId);
        result.UserName.Should().Be("rafael");
        result.Email.Should().Be("r@example.com");
    }

    [Fact]
    public async Task GetPublicProfile_UserNotFound_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var targetUserId = Guid.NewGuid();
        userManager.Setup(m => m.FindByIdAsync(targetUserId.ToString())).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new GetPublicProfileHandler(userManager.Object)
            .Handle(new GetPublicProfileQuery(targetUserId), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("User not found.");
    }
}
