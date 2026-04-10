using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.AI.Services;
using FreestyleCombo.API.Features.Combos.GenerateCombo;

using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class GenerateComboHandlerTests
{
    private readonly Mock<ITrickRepository> _trickRepo = new();
    private readonly Mock<IComboRepository> _comboRepo = new();
    private readonly Mock<IUserPreferenceRepository> _prefRepo = new();
    private readonly Mock<IComboEnhancerService> _enhancer = new();
    private readonly Mock<IHttpContextAccessor> _httpContextAccessor = new();
    private readonly Mock<UserManager<AppUser>> _userManager = new(
        Mock.Of<IUserStore<AppUser>>(), null, null, null, null, null, null, null, null);
    private readonly Guid _userId = Guid.NewGuid();

    public GenerateComboHandlerTests()
    {

        var user = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(ClaimTypes.NameIdentifier, _userId.ToString())
        ], "test"));

        var httpContext = new DefaultHttpContext { User = user };
        _httpContextAccessor.Setup(x => x.HttpContext).Returns(httpContext);

        _comboRepo.Setup(r => r.AddAsync(It.IsAny<Combo>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _enhancer.Setup(e => e.EnhanceAsync(It.IsAny<FreestyleCombo.AI.Models.ComboEnhancementRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new FreestyleCombo.AI.Models.ComboEnhancementResponse { Description = "Test AI description." });
    }

    private GenerateComboHandler CreateHandler() => new(
        _trickRepo.Object,
        _comboRepo.Object,
        _prefRepo.Object,
        _enhancer.Object,
        _httpContextAccessor.Object,
        _userManager.Object
    );

    [Fact]
    public async Task Handle_WithDefaultOverrides_ReturnsComboWithCorrectLength()
    {
        var tricks = TrickFaker.DefaultPool();
        _trickRepo.Setup(r => r.GetAllAsync(It.IsAny<bool?>(), It.IsAny<bool?>(), It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(tricks);
        _prefRepo.Setup(r => r.GetByUserIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((UserPreference?)null);

        var handler = CreateHandler();
        var command = new GenerateComboCommand(false, new GenerateComboOverrides { ComboLength = 5 });

        var result = await handler.Handle(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.TrickCount.Should().Be(5);
        result.Tricks.Should().HaveCount(5);
        result.Tricks.Select(t => t.Position).Should().BeEquivalentTo([1, 2, 3, 4, 5]);
    }

    [Fact]
    public async Task Handle_WhenNoTricksMatchFilter_ThrowsInvalidOperationException()
    {
        _trickRepo.Setup(r => r.GetAllAsync(It.IsAny<bool?>(), It.IsAny<bool?>(), It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(TrickFaker.DefaultPool());
        _prefRepo.Setup(r => r.GetByUserIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((UserPreference?)null);

        var handler = CreateHandler();
        // MaxDifficulty = 0 will exclude all tricks
        var command = new GenerateComboCommand(false, new GenerateComboOverrides { MaxDifficulty = 0, ComboLength = 4 });

        Func<Task> act = () => handler.Handle(command, CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("No tricks match your preferences.");
    }

    [Fact]
    public async Task Handle_NoTouchOnlyAppliedToCrossoverTricks()
    {
        // Use only non-crossover tricks — no NoTouch should appear
        var tricks = TrickFaker.CreateMany(6, crossOver: false);
        _trickRepo.Setup(r => r.GetAllAsync(It.IsAny<bool?>(), It.IsAny<bool?>(), It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(tricks);
        _prefRepo.Setup(r => r.GetByUserIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((UserPreference?)null);

        var handler = CreateHandler();
        var command = new GenerateComboCommand(false, new GenerateComboOverrides
        {
            ComboLength = 6,
            NoTouchPercentage = 100,
            IncludeCrossOver = false
        });

        var result = await handler.Handle(command, CancellationToken.None);

        result.Tricks.Should().OnlyContain(t => !t.NoTouch);
    }

    [Fact]
    public async Task Handle_DisplayText_FormatsCorrectly()
    {
        var tricks = TrickFaker.DefaultPool();
        _trickRepo.Setup(r => r.GetAllAsync(It.IsAny<bool?>(), It.IsAny<bool?>(), It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(tricks);
        _prefRepo.Setup(r => r.GetByUserIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((UserPreference?)null);

        var handler = CreateHandler();
        var command = new GenerateComboCommand(false, new GenerateComboOverrides { ComboLength = 3, NoTouchPercentage = 0 });

        var result = await handler.Handle(command, CancellationToken.None);

        result.DisplayText.Should().NotContain("(nt)");
        result.DisplayText.Split(' ').Should().HaveCount(3);
    }

    [Fact]
    public async Task Handle_UsesUserPreferences_WhenUsePreferencesIsTrue()
    {
        var tricks = TrickFaker.DefaultPool();
        _trickRepo.Setup(r => r.GetAllAsync(It.IsAny<bool?>(), It.IsAny<bool?>(), It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(tricks);

        var savedPref = new UserPreference
        {
            Id = Guid.NewGuid(),
            UserId = _userId,
            ComboLength = 4,
            MaxDifficulty = 5
        };
        _prefRepo.Setup(r => r.GetByUserIdAsync(_userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(savedPref);

        var handler = CreateHandler();
        var command = new GenerateComboCommand(true, null);

        var result = await handler.Handle(command, CancellationToken.None);

        result.TrickCount.Should().Be(4);
    }
}
