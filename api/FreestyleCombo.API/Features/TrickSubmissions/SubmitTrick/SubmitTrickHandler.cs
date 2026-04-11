using System.Security.Claims;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.TrickSubmissions.SubmitTrick;

public class SubmitTrickHandler : IRequestHandler<SubmitTrickCommand, Guid>
{
    private readonly ITrickSubmissionRepository _repo;
    private readonly ITrickRepository _trickRepo;
    private readonly IHttpContextAccessor _http;

    public SubmitTrickHandler(ITrickSubmissionRepository repo, ITrickRepository trickRepo, IHttpContextAccessor http)
    {
        _repo = repo;
        _trickRepo = trickRepo;
        _http = http;
    }

    public async Task<Guid> Handle(SubmitTrickCommand request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isAdmin = _http.HttpContext.User.IsInRole("Admin");

        var now = DateTime.UtcNow;
        var status = isAdmin ? SubmissionStatus.Approved : SubmissionStatus.Pending;

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
            Status = status,
            SubmittedAt = now,
            SubmittedById = userId,
            ReviewedAt = isAdmin ? now : null,
            ReviewedById = isAdmin ? userId : null
        };

        await _repo.AddAsync(submission, cancellationToken);

        if (isAdmin)
        {
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
        }

        return submission.Id;
    }
}
