using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Tricks.GetTricks;

public class GetTricksHandler : IRequestHandler<GetTricksQuery, List<TrickListItemDto>>
{
    private readonly ITrickRepository _repo;

    public GetTricksHandler(ITrickRepository repo) => _repo = repo;

    public async Task<List<TrickListItemDto>> Handle(GetTricksQuery request, CancellationToken cancellationToken)
    {
        var tricks = await _repo.GetAllAsync(request.CrossOver, request.Knee, request.MaxDifficulty, cancellationToken);
        return tricks.Select(t => new TrickListItemDto
        {
            Type = "trick",
            Id = t.Id,
            Name = t.Name,
            Abbreviation = t.Abbreviation,
            CrossOver = t.CrossOver,
            Knee = t.Knee,
            Revolution = t.Revolution,
            Difficulty = t.Difficulty,
            IsTransition = t.IsTransition
        }).ToList();
    }
}
