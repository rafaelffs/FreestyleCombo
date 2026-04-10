using FreestyleCombo.API.Features.TrickSubmissions;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.TrickSubmissions.GetPendingSubmissions;

public class GetPendingSubmissionsHandler : IRequestHandler<GetPendingSubmissionsQuery, List<TrickSubmissionDto>>
{
    private readonly ITrickSubmissionRepository _repo;

    public GetPendingSubmissionsHandler(ITrickSubmissionRepository repo) => _repo = repo;

    public async Task<List<TrickSubmissionDto>> Handle(GetPendingSubmissionsQuery request, CancellationToken cancellationToken)
    {
        var submissions = await _repo.GetPendingAsync(cancellationToken);
        return submissions.Select(TrickSubmissionDto.From).ToList();
    }
}
