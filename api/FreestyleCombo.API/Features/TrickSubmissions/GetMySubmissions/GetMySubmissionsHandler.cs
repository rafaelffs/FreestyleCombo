using System.Security.Claims;
using FreestyleCombo.API.Features.TrickSubmissions;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.TrickSubmissions.GetMySubmissions;

public class GetMySubmissionsHandler : IRequestHandler<GetMySubmissionsQuery, List<TrickSubmissionDto>>
{
    private readonly ITrickSubmissionRepository _repo;
    private readonly IHttpContextAccessor _http;

    public GetMySubmissionsHandler(ITrickSubmissionRepository repo, IHttpContextAccessor http)
    {
        _repo = repo;
        _http = http;
    }

    public async Task<List<TrickSubmissionDto>> Handle(GetMySubmissionsQuery request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var submissions = await _repo.GetByUserIdAsync(userId, cancellationToken);
        return submissions.Select(TrickSubmissionDto.From).ToList();
    }
}
