using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Tricks.GetTricks;

public class GetTricksHandler : IRequestHandler<GetTricksQuery, List<TrickListItemDto>>
{
    private readonly ITrickRepository _repo;
    private readonly IComboRepository _comboRepo;

    public GetTricksHandler(ITrickRepository repo, IComboRepository comboRepo)
    {
        _repo = repo;
        _comboRepo = comboRepo;
    }

    public async Task<List<TrickListItemDto>> Handle(GetTricksQuery request, CancellationToken cancellationToken)
    {
        var tricks = await _repo.GetAllAsync(request.CrossOver, request.Knee, request.MaxDifficulty, cancellationToken);

        var trickItems = tricks.Select(t => new TrickListItemDto
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
        }).OrderBy(t => t.Name).ToList();

        var reusableCombos = await _comboRepo.GetReusableAsync(cancellationToken);

        var comboItems = reusableCombos.Select(c => new TrickListItemDto
        {
            Type = "combo",
            Id = c.Id,
            Name = c.Name,
            TotalDifficulty = (decimal?)c.TotalDifficulty,
            TrickCount = c.TrickCount,
            Tricks = c.ComboTricks
                .Where(ct => ct.TrickId.HasValue)
                .OrderBy(ct => ct.Position)
                .Select(ct => new ComboTrickDto
                {
                    TrickId = ct.TrickId,
                    Name = ct.Trick!.Name,
                    Abbreviation = ct.Trick.Abbreviation,
                    Position = ct.Position,
                    Difficulty = ct.Trick.Difficulty,
                    Revolution = ct.Trick.Revolution,
                    CrossOver = ct.Trick.CrossOver,
                    IsTransition = ct.Trick.IsTransition,
                    StrongFoot = ct.StrongFoot,
                    NoTouch = ct.NoTouch
                }).ToList()
        }).OrderBy(c => c.Name).ToList();

        var result = trickItems.ToList<TrickListItemDto>();
        result.AddRange(comboItems);
        return result;
    }
}
