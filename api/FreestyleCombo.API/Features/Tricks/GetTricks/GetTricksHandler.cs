using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Tricks.GetTricks;

public class GetTricksHandler : IRequestHandler<GetTricksQuery, List<TrickDto>>
{
    private readonly ITrickRepository _repo;

    public GetTricksHandler(ITrickRepository repo) => _repo = repo;

    public async Task<List<TrickDto>> Handle(GetTricksQuery request, CancellationToken cancellationToken)
    {
        var tricks = await _repo.GetAllAsync(request.CrossOver, request.Knee, request.MaxDifficulty, cancellationToken);
        return tricks.Select(t => new TrickDto(t.Id, t.Name, t.Abbreviation, t.CrossOver, t.Knee, t.Revolution, t.Difficulty, t.CommonLevel, t.IsTransition, t.CreatedBy, t.DateCreated, t.Notes)).ToList();
    }
}
