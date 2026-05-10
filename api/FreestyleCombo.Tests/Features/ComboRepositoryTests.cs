using FluentAssertions;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Infrastructure.Data;
using FreestyleCombo.Infrastructure.Repositories;
using FreestyleCombo.Tests.Helpers;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Tests.Features;

public class ComboRepositoryTests
{
    private static AppDbContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AppDbContext(options);
    }

    private static AppUser CreateUser() =>
        new() { Id = Guid.NewGuid(), UserName = "testuser", Email = "test@example.com", NormalizedUserName = "TESTUSER", NormalizedEmail = "TEST@EXAMPLE.COM", SecurityStamp = Guid.NewGuid().ToString() };

    private static Combo CreateCombo(AppUser owner, bool isReusable = false, ComboVisibility visibility = ComboVisibility.Private) =>
        new()
        {
            Id = Guid.NewGuid(),
            OwnerId = owner.Id,
            Owner = owner,
            Name = "Test Combo",
            AverageDifficulty = 3.0,
            TrickCount = 1,
            Visibility = visibility,
            CreatedAt = DateTime.UtcNow,
            IsReusable = isReusable
        };

    [Fact]
    public async Task GetReusableAsync_ReturnsOnlyReusableCombos()
    {
        await using var db = CreateDb();
        var user = CreateUser();
        await db.Users.AddAsync(user);

        var trick = TrickFaker.Create();
        await db.Tricks.AddAsync(trick);

        var reusable1 = CreateCombo(user, isReusable: true);
        var reusable2 = CreateCombo(user, isReusable: true);
        var nonReusable = CreateCombo(user, isReusable: false);

        reusable1.ComboTricks.Add(new ComboTrick { Id = Guid.NewGuid(), ComboId = reusable1.Id, TrickId = trick.Id, Position = 1 });

        await db.Combos.AddRangeAsync(reusable1, reusable2, nonReusable);
        await db.SaveChangesAsync();

        var repo = new ComboRepository(db);
        var result = await repo.GetReusableAsync();

        result.Should().HaveCount(2);
        result.Select(c => c.Id).Should().BeEquivalentTo(new[] { reusable1.Id, reusable2.Id });
    }

    [Fact]
    public async Task GetReusableAsync_EagerLoadsTricks()
    {
        await using var db = CreateDb();
        var user = CreateUser();
        await db.Users.AddAsync(user);

        var trick = TrickFaker.Create();
        await db.Tricks.AddAsync(trick);

        var reusable = CreateCombo(user, isReusable: true);
        reusable.ComboTricks.Add(new ComboTrick { Id = Guid.NewGuid(), ComboId = reusable.Id, TrickId = trick.Id, Position = 1 });

        await db.Combos.AddAsync(reusable);
        await db.SaveChangesAsync();

        var repo = new ComboRepository(db);
        var result = await repo.GetReusableAsync();

        result.Should().HaveCount(1);
        result[0].ComboTricks.Should().HaveCount(1);
        result[0].ComboTricks.First().Trick.Should().NotBeNull();
        result[0].ComboTricks.First().Trick!.Id.Should().Be(trick.Id);
    }

    [Fact]
    public async Task GetReusableAsync_WhenNoReusableCombos_ReturnsEmptyList()
    {
        await using var db = CreateDb();
        var user = CreateUser();
        await db.Users.AddAsync(user);

        var nonReusable = CreateCombo(user, isReusable: false);
        await db.Combos.AddAsync(nonReusable);
        await db.SaveChangesAsync();

        var repo = new ComboRepository(db);
        var result = await repo.GetReusableAsync();

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task IsReferencedAsSubComboAsync_ReturnsTrueWhenComboIsUsedAsSubCombo()
    {
        await using var db = CreateDb();
        var user = CreateUser();
        await db.Users.AddAsync(user);

        var subCombo = CreateCombo(user, isReusable: true);
        var parentCombo = CreateCombo(user);
        await db.Combos.AddRangeAsync(subCombo, parentCombo);
        await db.SaveChangesAsync();

        // Add a ComboTrick that references subCombo as a sub-combo
        var ct = new ComboTrick
        {
            Id = Guid.NewGuid(),
            ComboId = parentCombo.Id,
            SubComboId = subCombo.Id,
            TrickId = null,
            Position = 1
        };
        await db.ComboTricks.AddAsync(ct);
        await db.SaveChangesAsync();

        var repo = new ComboRepository(db);
        var result = await repo.IsReferencedAsSubComboAsync(subCombo.Id);

        result.Should().BeTrue();
    }

    [Fact]
    public async Task IsReferencedAsSubComboAsync_ReturnsFalseWhenComboIsNotUsedAsSubCombo()
    {
        await using var db = CreateDb();
        var user = CreateUser();
        await db.Users.AddAsync(user);

        var trick = TrickFaker.Create();
        await db.Tricks.AddAsync(trick);

        var unusedCombo = CreateCombo(user, isReusable: true);
        var parentCombo = CreateCombo(user);
        await db.Combos.AddRangeAsync(unusedCombo, parentCombo);
        await db.SaveChangesAsync();

        // parentCombo references a trick, not unusedCombo
        var ct = new ComboTrick
        {
            Id = Guid.NewGuid(),
            ComboId = parentCombo.Id,
            TrickId = trick.Id,
            SubComboId = null,
            Position = 1
        };
        await db.ComboTricks.AddAsync(ct);
        await db.SaveChangesAsync();

        var repo = new ComboRepository(db);
        var result = await repo.IsReferencedAsSubComboAsync(unusedCombo.Id);

        result.Should().BeFalse();
    }

    [Fact]
    public async Task IsReferencedAsSubComboAsync_ReturnsFalseForNonExistentComboId()
    {
        await using var db = CreateDb();
        var repo = new ComboRepository(db);

        var result = await repo.IsReferencedAsSubComboAsync(Guid.NewGuid());

        result.Should().BeFalse();
    }
}
