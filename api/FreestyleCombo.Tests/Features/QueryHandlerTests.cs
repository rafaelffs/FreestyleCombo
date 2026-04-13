using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.API.Features.Admin;
using FreestyleCombo.API.Features.Preferences.GetPreferences;
using FreestyleCombo.API.Features.Ratings.GetRatings;
using FreestyleCombo.API.Features.Tricks.GetTricks;
using FreestyleCombo.API.Features.TrickSubmissions;
using FreestyleCombo.API.Features.TrickSubmissions.GetMySubmissions;
using FreestyleCombo.API.Features.TrickSubmissions.GetPendingSubmissions;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Tests.Helpers;
using Microsoft.AspNetCore.Http;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class QueryHandlerTests
{
    [Fact]
    public async Task GetTricks_ReturnsMappedDtos()
    {
        var repo = new Mock<ITrickRepository>();
        var tricks = new List<Trick>
        {
            TrickFaker.Create(name: "ATW", crossOver: false, knee: false, revolution: 1.0m, difficulty: 2, commonLevel: 3),
            TrickFaker.Create(name: "MATW", crossOver: true, knee: false, revolution: 2.0m, difficulty: 4, commonLevel: 5)
        };
        repo.Setup(r => r.GetAllAsync(true, false, 5, It.IsAny<CancellationToken>())).ReturnsAsync(tricks);

        var result = await new GetTricksHandler(repo.Object)
            .Handle(new GetTricksQuery(true, false, 5), CancellationToken.None);

        result.Should().HaveCount(2);
        result[0].Name.Should().Be("ATW");
        result[1].Revolution.Should().Be(2.0m);
    }

    [Fact]
    public async Task GetPreferences_ReturnsMappedDtos()
    {
        var repo = new Mock<IUserPreferenceRepository>();
        var userId = Guid.NewGuid();
        repo.Setup(r => r.GetAllByUserIdAsync(userId, It.IsAny<CancellationToken>())).ReturnsAsync(
        [
            new UserPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Name = "Default",
                MaxDifficulty = 5,
                ComboLength = 4,
                StrongFootPercentage = 60,
                NoTouchPercentage = 20,
                MaxConsecutiveNoTouch = 2,
                IncludeCrossOver = true,
                IncludeKnee = false,
                AllowedRevolutions = [1m, 2m]
            }
        ]);

        var result = await new GetPreferencesHandler(repo.Object)
            .Handle(new GetPreferencesQuery(userId), CancellationToken.None);

        result.Should().HaveCount(1);
        result[0].Name.Should().Be("Default");
        result[0].AllowedRevolutions.Should().BeEquivalentTo(new List<decimal> { 1m, 2m });
    }

    [Fact]
    public async Task GetRatings_RoundsAverageAndReturnsDistribution()
    {
        var repo = new Mock<IComboRatingRepository>();
        var comboId = Guid.NewGuid();
        var distribution = new Dictionary<int, int> { [5] = 2, [4] = 1 };
        repo.Setup(r => r.GetStatsAsync(comboId, It.IsAny<CancellationToken>())).ReturnsAsync((4.236, 3, distribution));

        var result = await new GetRatingsHandler(repo.Object)
            .Handle(new GetRatingsQuery(comboId), CancellationToken.None);

        result.AverageScore.Should().Be(4.24);
        result.TotalCount.Should().Be(3);
        result.Distribution.Should().BeSameAs(distribution);
    }

    [Fact]
    public async Task GetPendingApprovalsCount_ReturnsCombinedCount()
    {
        var comboRepo = new Mock<IComboRepository>();
        var submissionRepo = new Mock<ITrickSubmissionRepository>();
        comboRepo.Setup(r => r.GetPendingReviewCountAsync(It.IsAny<CancellationToken>())).ReturnsAsync(2);
        submissionRepo.Setup(r => r.GetPendingCountAsync(It.IsAny<CancellationToken>())).ReturnsAsync(3);

        var result = await new GetPendingApprovalsCountHandler(comboRepo.Object, submissionRepo.Object)
            .Handle(new GetPendingApprovalsCountQuery(), CancellationToken.None);

        result.Should().Be(5);
    }

    [Fact]
    public async Task GetPendingSubmissions_ReturnsMappedDtos()
    {
        var repo = new Mock<ITrickSubmissionRepository>();
        repo.Setup(r => r.GetPendingAsync(It.IsAny<CancellationToken>())).ReturnsAsync(
        [
            new TrickSubmission
            {
                Id = Guid.NewGuid(),
                Name = "ATW",
                Abbreviation = "ATW",
                Difficulty = 2,
                CommonLevel = 3,
                Revolution = 1.0m,
                Status = SubmissionStatus.Pending,
                SubmittedBy = new AppUser { UserName = "rafael" },
                SubmittedAt = DateTime.UtcNow
            }
        ]);

        var result = await new GetPendingSubmissionsHandler(repo.Object)
            .Handle(new GetPendingSubmissionsQuery(), CancellationToken.None);

        result.Should().HaveCount(1);
        result[0].Status.Should().Be("Pending");
        result[0].SubmittedByUserName.Should().Be("rafael");
    }

    [Fact]
    public async Task GetMySubmissions_UsesCurrentUserId()
    {
        var repo = new Mock<ITrickSubmissionRepository>();
        var http = new Mock<IHttpContextAccessor>();
        var userId = Guid.NewGuid();
        http.Setup(x => x.HttpContext).Returns(new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
            [
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            ], "test"))
        });
        repo.Setup(r => r.GetByUserIdAsync(userId, It.IsAny<CancellationToken>())).ReturnsAsync(
        [
            new TrickSubmission
            {
                Id = Guid.NewGuid(),
                Name = "ATW",
                Abbreviation = "ATW",
                Difficulty = 2,
                CommonLevel = 3,
                Revolution = 1.0m,
                Status = SubmissionStatus.Pending,
                SubmittedBy = new AppUser { UserName = "rafael" },
                SubmittedAt = DateTime.UtcNow,
                SubmittedById = userId
            }
        ]);

        var result = await new GetMySubmissionsHandler(repo.Object, http.Object)
            .Handle(new GetMySubmissionsQuery(), CancellationToken.None);

        result.Should().HaveCount(1);
        result[0].Name.Should().Be("ATW");
        repo.Verify(r => r.GetByUserIdAsync(userId, It.IsAny<CancellationToken>()), Times.Once);
    }
}
