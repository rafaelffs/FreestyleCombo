using FluentAssertions;
using FreestyleCombo.API.Features.Admin;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class AdminHandlerTests
{
    private static Mock<UserManager<AppUser>> CreateUserManagerMock()
    {
        return new Mock<UserManager<AppUser>>(
            Mock.Of<IUserStore<AppUser>>(),
            null!, null!, null!, null!, null!, null!, null!, null!);
    }

    [Fact]
    public async Task GetUsers_ReturnsSortedUsersWithRoleAndComboCounts()
    {
        var userManager = CreateUserManagerMock();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        await using var db = new AppDbContext(options);
        var alpha = new AppUser { Id = Guid.NewGuid(), UserName = "alpha", Email = "a@example.com" };
        var zeta = new AppUser { Id = Guid.NewGuid(), UserName = "zeta", Email = "z@example.com" };
        db.Users.AddRange(alpha, zeta);
        db.Combos.AddRange(
            new Combo { Id = Guid.NewGuid(), OwnerId = alpha.Id },
            new Combo { Id = Guid.NewGuid(), OwnerId = alpha.Id },
            new Combo { Id = Guid.NewGuid(), OwnerId = zeta.Id });
        await db.SaveChangesAsync();

        userManager.SetupGet(m => m.Users).Returns(db.Users);
        userManager.Setup(m => m.GetRolesAsync(It.Is<AppUser>(u => u.Id == alpha.Id))).ReturnsAsync(["Admin"]);
        userManager.Setup(m => m.GetRolesAsync(It.Is<AppUser>(u => u.Id == zeta.Id))).ReturnsAsync([]);

        var result = await new GetUsersHandler(userManager.Object, db)
            .Handle(new GetUsersQuery(), CancellationToken.None);

        result.Select(r => r.UserName).Should().Equal(["alpha", "zeta"]);
        result[0].IsAdmin.Should().BeTrue();
        result[0].ComboCount.Should().Be(2);
        result[1].ComboCount.Should().Be(1);
    }

    [Fact]
    public async Task UpdateUser_ChangesFields_ReturnsDto()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId, UserName = "old", Email = "old@example.com" };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.SetUserNameAsync(user, "new"))
            .Callback<AppUser, string>((target, userName) => target.UserName = userName)
            .ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.GenerateChangeEmailTokenAsync(user, "new@example.com")).ReturnsAsync("token");
        userManager.Setup(m => m.ChangeEmailAsync(user, "new@example.com", "token"))
            .Callback<AppUser, string, string>((target, email, _) => target.Email = email)
            .ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.GetRolesAsync(user)).ReturnsAsync(["Admin"]);

        var result = await new UpdateUserHandler(userManager.Object)
            .Handle(new UpdateUserCommand(userId, "new", "new@example.com"), CancellationToken.None);

        result.UserName.Should().Be("new");
        result.Email.Should().Be("new@example.com");
        result.IsAdmin.Should().BeTrue();
    }

    [Fact]
    public async Task UpdateUser_NotFound_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new UpdateUserHandler(userManager.Object)
            .Handle(new UpdateUserCommand(userId, "new", null), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("User not found.");
    }

    [Fact]
    public async Task UpdateUser_SetUserNameFailure_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId, UserName = "old", Email = "old@example.com" };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.SetUserNameAsync(user, "new"))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "Duplicate username" }));

        Func<Task> act = () => new UpdateUserHandler(userManager.Object)
            .Handle(new UpdateUserCommand(userId, "new", null), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Duplicate username");
    }

    [Fact]
    public async Task ResetUserPassword_Success_CallsRemoveAndAdd()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.RemovePasswordAsync(user)).ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.AddPasswordAsync(user, "newpass1")).ReturnsAsync(IdentityResult.Success);

        await new ResetUserPasswordHandler(userManager.Object)
            .Handle(new ResetUserPasswordCommand(userId, "newpass1"), CancellationToken.None);

        userManager.Verify(m => m.RemovePasswordAsync(user), Times.Once);
        userManager.Verify(m => m.AddPasswordAsync(user, "newpass1"), Times.Once);
    }

    [Fact]
    public async Task ResetUserPassword_NotFound_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new ResetUserPasswordHandler(userManager.Object)
            .Handle(new ResetUserPasswordCommand(userId, "newpass1"), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("User not found.");
    }

    [Fact]
    public async Task ResetUserPassword_RemoveFailure_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.RemovePasswordAsync(user))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "Remove failed" }));

        Func<Task> act = () => new ResetUserPasswordHandler(userManager.Object)
            .Handle(new ResetUserPasswordCommand(userId, "newpass1"), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Remove failed");
    }

    [Fact]
    public async Task ResetUserPassword_AddFailure_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.RemovePasswordAsync(user)).ReturnsAsync(IdentityResult.Success);
        userManager.Setup(m => m.AddPasswordAsync(user, "newpass1"))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "Add failed" }));

        Func<Task> act = () => new ResetUserPasswordHandler(userManager.Object)
            .Handle(new ResetUserPasswordCommand(userId, "newpass1"), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Add failed");
    }

    [Fact]
    public async Task UpdateUserRole_AddsAdminRoleWhenNeeded()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.IsInRoleAsync(user, "Admin")).ReturnsAsync(false);
        userManager.Setup(m => m.AddToRoleAsync(user, "Admin")).ReturnsAsync(IdentityResult.Success);

        await new UpdateUserRoleHandler(userManager.Object)
            .Handle(new UpdateUserRoleCommand(userId, true), CancellationToken.None);

        userManager.Verify(m => m.AddToRoleAsync(user, "Admin"), Times.Once);
    }

    [Fact]
    public async Task UpdateUserRole_RemovesAdminRoleWhenNeeded()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.IsInRoleAsync(user, "Admin")).ReturnsAsync(true);
        userManager.Setup(m => m.RemoveFromRoleAsync(user, "Admin")).ReturnsAsync(IdentityResult.Success);

        await new UpdateUserRoleHandler(userManager.Object)
            .Handle(new UpdateUserRoleCommand(userId, false), CancellationToken.None);

        userManager.Verify(m => m.RemoveFromRoleAsync(user, "Admin"), Times.Once);
    }

    [Fact]
    public async Task UpdateUserRole_NoOp_DoesNotMutateRoles()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.IsInRoleAsync(user, "Admin")).ReturnsAsync(true);

        await new UpdateUserRoleHandler(userManager.Object)
            .Handle(new UpdateUserRoleCommand(userId, true), CancellationToken.None);

        userManager.Verify(m => m.AddToRoleAsync(It.IsAny<AppUser>(), It.IsAny<string>()), Times.Never);
        userManager.Verify(m => m.RemoveFromRoleAsync(It.IsAny<AppUser>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task UpdateUserRole_NotFound_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new UpdateUserRoleHandler(userManager.Object)
            .Handle(new UpdateUserRoleCommand(userId, true), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("User not found.");
    }

    [Fact]
    public async Task DeleteUser_Success_CallsDeleteAsync()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.DeleteAsync(user)).ReturnsAsync(IdentityResult.Success);

        await new DeleteUserHandler(userManager.Object)
            .Handle(new DeleteUserCommand(userId), CancellationToken.None);

        userManager.Verify(m => m.DeleteAsync(user), Times.Once);
    }

    [Fact]
    public async Task DeleteUser_NotFound_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync((AppUser?)null);

        Func<Task> act = () => new DeleteUserHandler(userManager.Object)
            .Handle(new DeleteUserCommand(userId), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("User not found.");
    }

    [Fact]
    public async Task DeleteUser_Failure_ThrowsInvalidOperationException()
    {
        var userManager = CreateUserManagerMock();
        var userId = Guid.NewGuid();
        var user = new AppUser { Id = userId };
        userManager.Setup(m => m.FindByIdAsync(userId.ToString())).ReturnsAsync(user);
        userManager.Setup(m => m.DeleteAsync(user))
            .ReturnsAsync(IdentityResult.Failed(new IdentityError { Description = "Delete failed" }));

        Func<Task> act = () => new DeleteUserHandler(userManager.Object)
            .Handle(new DeleteUserCommand(userId), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Delete failed");
    }
}
