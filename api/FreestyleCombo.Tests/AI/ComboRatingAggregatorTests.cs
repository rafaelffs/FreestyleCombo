using FluentAssertions;
using FreestyleCombo.AI.Training;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Microsoft.Extensions.Logging;
using Moq;

namespace FreestyleCombo.Tests.AI;

public class ComboRatingAggregatorTests
{
    [Fact]
    public async Task AdjustWeightsAsync_IncreasesCommonLevel_WhenAverageHighAndEnoughScores()
    {
        var ratingRepo = new Mock<IComboRatingRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var trickRepo = new Mock<ITrickRepository>();
        var trick = new Trick
        {
            Id = Guid.NewGuid(),
            Abbreviation = "ATW",
            CommonLevel = 3,
            ComboTricks =
            [
                new ComboTrick { ComboId = Guid.NewGuid() },
                new ComboTrick { ComboId = Guid.NewGuid() },
                new ComboTrick { ComboId = Guid.NewGuid() }
            ]
        };
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([trick]);
        ratingRepo.Setup(r => r.GetByComboAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(
        [
            new ComboRating { Score = 5 },
            new ComboRating { Score = 4 }
        ]);
        trickRepo.Setup(r => r.UpdateAsync(trick, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new ComboRatingAggregator(ratingRepo.Object, comboRepo.Object, trickRepo.Object, Mock.Of<ILogger<ComboRatingAggregator>>())
            .AdjustWeightsAsync();

        trick.CommonLevel.Should().Be(4);
        trickRepo.Verify(r => r.UpdateAsync(trick, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task AdjustWeightsAsync_DecreasesCommonLevel_WhenAverageLowAndEnoughScores()
    {
        var ratingRepo = new Mock<IComboRatingRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var trickRepo = new Mock<ITrickRepository>();
        var trick = new Trick
        {
            Id = Guid.NewGuid(),
            Abbreviation = "ATW",
            CommonLevel = 4,
            ComboTricks =
            [
                new ComboTrick { ComboId = Guid.NewGuid() },
                new ComboTrick { ComboId = Guid.NewGuid() },
                new ComboTrick { ComboId = Guid.NewGuid() }
            ]
        };
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([trick]);
        ratingRepo.Setup(r => r.GetByComboAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(
        [
            new ComboRating { Score = 1 },
            new ComboRating { Score = 2 }
        ]);
        trickRepo.Setup(r => r.UpdateAsync(trick, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new ComboRatingAggregator(ratingRepo.Object, comboRepo.Object, trickRepo.Object, Mock.Of<ILogger<ComboRatingAggregator>>())
            .AdjustWeightsAsync();

        trick.CommonLevel.Should().Be(3);
        trickRepo.Verify(r => r.UpdateAsync(trick, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task AdjustWeightsAsync_DoesNothing_WhenLessThanThreeScores()
    {
        var ratingRepo = new Mock<IComboRatingRepository>();
        var comboRepo = new Mock<IComboRepository>();
        var trickRepo = new Mock<ITrickRepository>();
        var trick = new Trick
        {
            Id = Guid.NewGuid(),
            Abbreviation = "ATW",
            CommonLevel = 3,
            ComboTricks =
            [
                new ComboTrick { ComboId = Guid.NewGuid() },
                new ComboTrick { ComboId = Guid.NewGuid() }
            ]
        };
        trickRepo.Setup(r => r.GetAllAsync(null, null, null, It.IsAny<CancellationToken>())).ReturnsAsync([trick]);
        ratingRepo.Setup(r => r.GetByComboAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(
        [
            new ComboRating { Score = 5 }
        ]);

        await new ComboRatingAggregator(ratingRepo.Object, comboRepo.Object, trickRepo.Object, Mock.Of<ILogger<ComboRatingAggregator>>())
            .AdjustWeightsAsync();

        trick.CommonLevel.Should().Be(3);
        trickRepo.Verify(r => r.UpdateAsync(It.IsAny<Trick>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}
