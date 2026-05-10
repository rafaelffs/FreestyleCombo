using FluentAssertions;
using FreestyleCombo.API.Features.Tricks.GetTricks;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class GetTricksHandlerTests
{
    private readonly Mock<ITrickRepository> _trickRepo = new();
    private readonly Mock<IComboRepository> _comboRepo = new();

    private GetTricksHandler CreateHandler() => new(_trickRepo.Object, _comboRepo.Object);

    private static Combo MakeReusableCombo(string name, params Trick[] tricks)
    {
        var combo = new Combo
        {
            Id = Guid.NewGuid(),
            Name = name,
            IsReusable = true,
            AverageDifficulty = tricks.Length > 0 ? tricks.Average(t => t.Difficulty) : 0,
            TrickCount = tricks.Length,
            ComboTricks = tricks.Select((t, i) => new ComboTrick
            {
                Id = Guid.NewGuid(),
                TrickId = t.Id,
                Trick = t,
                Position = i + 1
            }).ToList()
        };
        return combo;
    }

    [Fact]
    public async Task GetTricks_ReturnsOnlyTricks_WhenNoReusableCombos()
    {
        var tricks = TrickFaker.CreateMany(3);
        _trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync(tricks);
        _comboRepo.Setup(r => r.GetReusableAsync(It.IsAny<CancellationToken>())).ReturnsAsync([]);

        var result = await CreateHandler().Handle(new GetTricksQuery(null, null, null), CancellationToken.None);

        result.Should().HaveCount(3);
        result.Should().OnlyContain(r => r.Type == "trick");
    }

    [Fact]
    public async Task GetTricks_IncludesReusableCombos_InResults()
    {
        var trickA = TrickFaker.Create(name: "ATW", difficulty: 2);
        var trickB = TrickFaker.Create(name: "HTW", difficulty: 3);
        _trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([trickA]);
        _comboRepo.Setup(r => r.GetReusableAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync([MakeReusableCombo("Warm Up Combo", trickA, trickB)]);

        var result = await CreateHandler().Handle(new GetTricksQuery(null, null, null), CancellationToken.None);

        result.Should().HaveCount(2);
        result.Should().ContainSingle(r => r.Type == "trick");
        result.Should().ContainSingle(r => r.Type == "combo");
        var combo = result.Single(r => r.Type == "combo");
        combo.Name.Should().Be("Warm Up Combo");
        combo.Tricks.Should().HaveCount(2);
        combo.TrickCount.Should().Be(2);
    }

    [Fact]
    public async Task GetTricks_TricksReturnedFirst_ThenCombos()
    {
        var trickZ = TrickFaker.Create(name: "Zebra Trick");
        var trickA = TrickFaker.Create(name: "Alpha Trick");
        _trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync([trickZ, trickA]);
        _comboRepo.Setup(r => r.GetReusableAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync([
                MakeReusableCombo("Zebra Combo", trickZ),
                MakeReusableCombo("Alpha Combo", trickA)
            ]);

        var result = await CreateHandler().Handle(new GetTricksQuery(null, null, null), CancellationToken.None);

        result.Should().HaveCount(4);
        // First two are tricks, sorted alphabetically
        result[0].Type.Should().Be("trick");
        result[0].Name.Should().Be("Alpha Trick");
        result[1].Type.Should().Be("trick");
        result[1].Name.Should().Be("Zebra Trick");
        // Last two are combos, sorted alphabetically
        result[2].Type.Should().Be("combo");
        result[2].Name.Should().Be("Alpha Combo");
        result[3].Type.Should().Be("combo");
        result[3].Name.Should().Be("Zebra Combo");
    }

    [Fact]
    public async Task GetTricks_FiltersApplyToTricksOnly_NotCombos()
    {
        // crossOver filter is applied to tricks; reusable combos always appear
        var crossOverTrick = TrickFaker.Create(name: "XO Trick", crossOver: true);
        var nonCrossOverTrick = TrickFaker.Create(name: "ATW", crossOver: false);
        var reusableCombo = MakeReusableCombo("Reusable Combo", nonCrossOverTrick);

        // When filtering by crossOver=true, only crossOver tricks are returned by the repo
        _trickRepo.Setup(r => r.GetAllAsync(true, null, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync([crossOverTrick]);
        _comboRepo.Setup(r => r.GetReusableAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync([reusableCombo]);

        var result = await CreateHandler().Handle(new GetTricksQuery(true, null, null), CancellationToken.None);

        result.Should().HaveCount(2);
        var trickResult = result.Single(r => r.Type == "trick");
        trickResult.Name.Should().Be("XO Trick");
        var comboResult = result.Single(r => r.Type == "combo");
        comboResult.Name.Should().Be("Reusable Combo");
    }
}
