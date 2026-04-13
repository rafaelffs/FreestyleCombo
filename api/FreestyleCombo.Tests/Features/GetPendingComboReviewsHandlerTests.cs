using FluentAssertions;
using FreestyleCombo.API.Features.Combos.GetPendingComboReviews;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class GetPendingComboReviewsHandlerTests
{
    [Fact]
    public async Task Handle_ReturnsMappedPendingReviewCombos()
    {
        var repo = new Mock<IComboRepository>();
        var trick = TrickFaker.Create(name: "ATW", crossOver: true, revolution: 1.0m, difficulty: 3, commonLevel: 4);
        var combo = new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = Guid.NewGuid(),
            Owner = new AppUser { UserName = "owner" },
            Name = "Pending Combo",
            AverageDifficulty = 3.0,
            TrickCount = 1,
            Visibility = ComboVisibility.PendingReview,
            CreatedAt = DateTime.UtcNow,
            AiDescription = "desc",
            ComboTricks =
            [
                new ComboTrick
                {
                    Id = Guid.NewGuid(),
                    ComboId = Guid.NewGuid(),
                    TrickId = trick.Id,
                    Trick = trick,
                    Position = 1,
                    StrongFoot = true,
                    NoTouch = true
                }
            ],
            Ratings =
            [
                new ComboRating { Score = 5 }
            ]
        };

        repo.Setup(r => r.GetPendingReviewAsync(It.IsAny<CancellationToken>())).ReturnsAsync([combo]);

        var result = await new GetPendingComboReviewsHandler(repo.Object)
            .Handle(new GetPendingComboReviewsQuery(), CancellationToken.None);

        result.Should().HaveCount(1);
        result[0].Id.Should().Be(combo.Id);
        result[0].OwnerUserName.Should().Be("owner");
        result[0].Name.Should().Be("Pending Combo");
        result[0].Visibility.Should().Be("PendingReview");
        result[0].DisplayText.Should().Be(trick.Abbreviation + "(nt)");
        result[0].Tricks.Should().HaveCount(1);
        result[0].AverageRating.Should().Be(0);
        result[0].TotalRatings.Should().Be(0);
        result[0].IsFavourited.Should().BeFalse();
    }
}
