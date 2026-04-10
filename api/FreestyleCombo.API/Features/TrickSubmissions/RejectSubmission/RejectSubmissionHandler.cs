using System.Security.Claims;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.TrickSubmissions.RejectSubmission;

public class RejectSubmissionHandler : IRequestHandler<RejectSubmissionCommand>
{
    private readonly ITrickSubmissionRepository _repo;
    private readonly IHttpContextAccessor _http;

    public RejectSubmissionHandler(ITrickSubmissionRepository repo, IHttpContextAccessor http)
    {
        _repo = repo;
        _http = http;
    }

    public async Task Handle(RejectSubmissionCommand request, CancellationToken cancellationToken)
    {
        var adminId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var submission = await _repo.GetByIdAsync(request.SubmissionId, cancellationToken)
            ?? throw new KeyNotFoundException("Submission not found.");

        if (submission.Status != SubmissionStatus.Pending)
            throw new InvalidOperationException("Only pending submissions can be rejected.");

        submission.Status = SubmissionStatus.Rejected;
        submission.ReviewedAt = DateTime.UtcNow;
        submission.ReviewedById = adminId;
        await _repo.UpdateAsync(submission, cancellationToken);
    }
}
