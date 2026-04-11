using System.Security.Claims;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.TrickSubmissions.ApproveSubmission;

public class ApproveSubmissionHandler : IRequestHandler<ApproveSubmissionCommand>
{
    private readonly ITrickSubmissionRepository _submissionRepo;
    private readonly ITrickRepository _trickRepo;
    private readonly IHttpContextAccessor _http;

    public ApproveSubmissionHandler(
        ITrickSubmissionRepository submissionRepo,
        ITrickRepository trickRepo,
        IHttpContextAccessor http)
    {
        _submissionRepo = submissionRepo;
        _trickRepo = trickRepo;
        _http = http;
    }

    public async Task Handle(ApproveSubmissionCommand request, CancellationToken cancellationToken)
    {
        var adminId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var submission = await _submissionRepo.GetByIdAsync(request.SubmissionId, cancellationToken)
            ?? throw new KeyNotFoundException("Submission not found.");

        if (submission.Status != SubmissionStatus.Pending)
            throw new InvalidOperationException("Only pending submissions can be approved.");

        var trick = new Trick
        {
            Id = Guid.NewGuid(),
            Name = submission.Name,
            Abbreviation = submission.Abbreviation,
            CrossOver = submission.CrossOver,
            Knee = submission.Knee,
            Revolution = submission.Revolution,
            Difficulty = submission.Difficulty,
            CommonLevel = submission.CommonLevel
        };

        await _trickRepo.AddAsync(trick, cancellationToken);

        submission.Status = SubmissionStatus.Approved;
        submission.ReviewedAt = DateTime.UtcNow;
        submission.ReviewedById = adminId;
        await _submissionRepo.UpdateAsync(submission, cancellationToken);
    }
}
