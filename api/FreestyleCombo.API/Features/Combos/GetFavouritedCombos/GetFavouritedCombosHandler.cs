using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetFavouritedCombos;

public class GetFavouritedCombosHandler : IRequestHandler<GetFavouritedCombosQuery, List<PublicComboDto>>
{
    private readonly IComboRepository _repo;
    private readonly IUserComboCompletionRepository _completionRepo;

    public GetFavouritedCombosHandler(IComboRepository repo, IUserComboCompletionRepository completionRepo)
    {
        _repo = repo;
        _completionRepo = completionRepo;
    }

    public async Task<List<PublicComboDto>> Handle(GetFavouritedCombosQuery request, CancellationToken cancellationToken)
    {
        var combos = await _repo.GetFavouritedByUserAsync(request.UserId, cancellationToken);
        var completedIds = await _completionRepo.GetCompletedComboIdsAsync(request.UserId, cancellationToken);
        var completionCounts = await _completionRepo.GetCompletionCountsAsync(combos.Select(c => c.Id), cancellationToken);

        return combos.Select(c => new PublicComboDto
        {
            Id = c.Id,
            OwnerId = c.OwnerId,
            OwnerUserName = c.Owner?.UserName,
            Name = c.Name,
            AverageDifficulty = c.AverageDifficulty,
            TrickCount = c.TrickCount,
            IsPublic = c.IsPublic,
            Visibility = c.Visibility.ToString(),
            CreatedAt = c.CreatedAt,
            DisplayText = string.Join(" ", c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => ct.NoTouch ? $"{ct.Trick.Abbreviation}(nt)" : ct.Trick.Abbreviation)),
            AiDescription = c.AiDescription,
            Tricks = c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => new ComboTrickDto
            {
                TrickId = ct.TrickId,
                Name = ct.Trick.Name,
                Abbreviation = ct.Trick.Abbreviation,
                Position = ct.Position,
                StrongFoot = ct.StrongFoot,
                NoTouch = ct.NoTouch,
                Difficulty = ct.Trick.Difficulty,
                Revolution = ct.Trick.Revolution
            }).ToList(),
            AverageRating = c.Ratings.Any() ? Math.Round(c.Ratings.Average(r => r.Score), 2) : 0,
            TotalRatings = c.Ratings.Count,
            IsFavourited = true,
            IsCompleted = completedIds.Contains(c.Id),
            CompletionCount = completionCounts.GetValueOrDefault(c.Id, 0)
        }).ToList();
    }
}
