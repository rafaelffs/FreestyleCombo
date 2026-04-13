using System.Security.Claims;
using FluentAssertions;
using FreestyleCombo.API.Features.TrickSubmissions.ApproveSubmission;
using FreestyleCombo.API.Features.TrickSubmissions.RejectSubmission;
using FreestyleCombo.API.Features.TrickSubmissions.SubmitTrick;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using Microsoft.AspNetCore.Http;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class TrickSubmissionHandlerTests
{
    private readonly Mock<ITrickSubmissionRepository> _submissionRepo = new();
    private readonly Mock<ITrickRepository> _trickRepo = new();
    private readonly Mock<IHttpContextAccessor> _http = new();
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _submissionId = Guid.NewGuid();

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

    private SubmitTrickCommand DefaultSubmitCommand() =>
        new("Around the World", "ATW", false, false, 1.0m, 3, 4);

    private TrickSubmission PendingSubmission() => new()
    {
        Id = _submissionId,
        Name = "ATW",
        Abbreviation = "ATW",
        CrossOver = false,
        Knee = false,
        Revolution = 1.0m,
        Difficulty = 3,
        CommonLevel = 4,
        Status = SubmissionStatus.Pending,
        SubmittedAt = DateTime.UtcNow,
        SubmittedById = _userId
    };

    [Fact]
    public async Task SubmitTrick_RegularUser_CreatesPendingSubmission()
    {
        SetupUser(_userId, isAdmin: false);
        TrickSubmission? saved = null;
        _submissionRepo
            .Setup(r => r.AddAsync(It.IsAny<TrickSubmission>(), It.IsAny<CancellationToken>()))
            .Callback<TrickSubmission, CancellationToken>((submission, _) => saved = submission)
            .Returns(Task.CompletedTask);

        var result = await new SubmitTrickHandler(_submissionRepo.Object, _trickRepo.Object, _http.Object)
            .Handle(DefaultSubmitCommand(), CancellationToken.None);

        result.Should().NotBeEmpty();
        saved.Should().NotBeNull();
        saved!.Status.Should().Be(SubmissionStatus.Pending);
        saved.ReviewedAt.Should().BeNull();
        _trickRepo.Verify(r => r.AddAsync(It.IsAny<Trick>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SubmitTrick_AdminUser_CreatesApprovedSubmissionAndTrick()
    {
        SetupUser(_userId, isAdmin: true);
        TrickSubmission? saved = null;
        _submissionRepo
            .Setup(r => r.AddAsync(It.IsAny<TrickSubmission>(), It.IsAny<CancellationToken>()))
            .Callback<TrickSubmission, CancellationToken>((submission, _) => saved = submission)
            .Returns(Task.CompletedTask);
        _trickRepo.Setup(r => r.AddAsync(It.IsAny<Trick>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new SubmitTrickHandler(_submissionRepo.Object, _trickRepo.Object, _http.Object)
            .Handle(DefaultSubmitCommand(), CancellationToken.None);

        saved.Should().NotBeNull();
        saved!.Status.Should().Be(SubmissionStatus.Approved);
        saved.ReviewedAt.Should().NotBeNull();
        _trickRepo.Verify(r => r.AddAsync(It.IsAny<Trick>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ApproveSubmission_PendingSubmission_CreatesApprovedTrickAndUpdatesStatus()
    {
        SetupUser(_userId, isAdmin: true);
        var submission = PendingSubmission();
        _submissionRepo.Setup(r => r.GetByIdAsync(_submissionId, It.IsAny<CancellationToken>())).ReturnsAsync(submission);
        _submissionRepo.Setup(r => r.UpdateAsync(submission, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        _trickRepo.Setup(r => r.AddAsync(It.IsAny<Trick>(), It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new ApproveSubmissionHandler(_submissionRepo.Object, _trickRepo.Object, _http.Object)
            .Handle(new ApproveSubmissionCommand(_submissionId), CancellationToken.None);

        submission.Status.Should().Be(SubmissionStatus.Approved);
        submission.ReviewedAt.Should().NotBeNull();
        submission.ReviewedById.Should().Be(_userId);
        _trickRepo.Verify(r => r.AddAsync(It.IsAny<Trick>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ApproveSubmission_NotFound_ThrowsKeyNotFoundException()
    {
        SetupUser(_userId, isAdmin: true);
        _submissionRepo.Setup(r => r.GetByIdAsync(_submissionId, It.IsAny<CancellationToken>())).ReturnsAsync((TrickSubmission?)null);

        Func<Task> act = () => new ApproveSubmissionHandler(_submissionRepo.Object, _trickRepo.Object, _http.Object)
            .Handle(new ApproveSubmissionCommand(_submissionId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task ApproveSubmission_AlreadyApproved_ThrowsInvalidOperationException()
    {
        SetupUser(_userId, isAdmin: true);
        var submission = PendingSubmission();
        submission.Status = SubmissionStatus.Approved;
        _submissionRepo.Setup(r => r.GetByIdAsync(_submissionId, It.IsAny<CancellationToken>())).ReturnsAsync(submission);

        Func<Task> act = () => new ApproveSubmissionHandler(_submissionRepo.Object, _trickRepo.Object, _http.Object)
            .Handle(new ApproveSubmissionCommand(_submissionId), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Only pending submissions can be approved.");
    }

    [Fact]
    public async Task RejectSubmission_PendingSubmission_UpdatesStatusToRejected()
    {
        SetupUser(_userId, isAdmin: true);
        var submission = PendingSubmission();
        _submissionRepo.Setup(r => r.GetByIdAsync(_submissionId, It.IsAny<CancellationToken>())).ReturnsAsync(submission);
        _submissionRepo.Setup(r => r.UpdateAsync(submission, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new RejectSubmissionHandler(_submissionRepo.Object, _http.Object)
            .Handle(new RejectSubmissionCommand(_submissionId), CancellationToken.None);

        submission.Status.Should().Be(SubmissionStatus.Rejected);
        submission.ReviewedAt.Should().NotBeNull();
        submission.ReviewedById.Should().Be(_userId);
    }

    [Fact]
    public async Task RejectSubmission_NotFound_ThrowsKeyNotFoundException()
    {
        SetupUser(_userId, isAdmin: true);
        _submissionRepo.Setup(r => r.GetByIdAsync(_submissionId, It.IsAny<CancellationToken>())).ReturnsAsync((TrickSubmission?)null);

        Func<Task> act = () => new RejectSubmissionHandler(_submissionRepo.Object, _http.Object)
            .Handle(new RejectSubmissionCommand(_submissionId), CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task RejectSubmission_AlreadyRejected_ThrowsInvalidOperationException()
    {
        SetupUser(_userId, isAdmin: true);
        var submission = PendingSubmission();
        submission.Status = SubmissionStatus.Rejected;
        _submissionRepo.Setup(r => r.GetByIdAsync(_submissionId, It.IsAny<CancellationToken>())).ReturnsAsync(submission);

        Func<Task> act = () => new RejectSubmissionHandler(_submissionRepo.Object, _http.Object)
            .Handle(new RejectSubmissionCommand(_submissionId), CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Only pending submissions can be rejected.");
    }
}
