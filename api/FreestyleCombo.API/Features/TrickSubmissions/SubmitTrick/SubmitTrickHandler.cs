using System.Security.Claims;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.TrickSubmissions.SubmitTrick;

public class SubmitTrickHandler : IRequestHandler<SubmitTrickCommand, Guid>
{
    private readonly ITrickSubmissionRepository _repo;
    private readonly IHttpContextAccessor _http;

    public SubmitTrickHandler(ITrickSubmissionRepository repo, IHttpContextAccessor http)
    {
        _repo = repo;
        _http = http;
    }

    public async Task<Guid> Handle(SubmitTrickCommand request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var submission = new TrickSubmission
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            Abbreviation = request.Abbreviation,
            CrossOver = request.CrossOver,
            Knee = request.Knee,
            Revolution = request.Revolution,
            Difficulty = request.Difficulty,
            CommonLevel = request.CommonLevel,
            Status = SubmissionStatus.Pending,
            SubmittedAt = DateTime.UtcNow,
            SubmittedById = userId
        };

        await _repo.AddAsync(submission, cancellationToken);
        return submission.Id;
    }
}
