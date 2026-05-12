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
            TotalDifficulty = c.TotalDifficulty,
            TrickCount = c.TrickCount,
            IsPublic = c.IsPublic,
            Visibility = c.Visibility.ToString(),
            CreatedAt = c.CreatedAt,
            DisplayText = string.Join(" ", c.ComboTricks.OrderBy(ct => ct.Position).Select(ct =>
            {
                if (ct.TrickId.HasValue)
                    return ct.NoTouch ? $"{ct.Trick!.Abbreviation}(nt)" : ct.Trick!.Abbreviation;
                else
                {
                    var inner = string.Join(" ", ct.SubCombo!.ComboTricks
                        .Where(sct => sct.TrickId.HasValue)
                        .OrderBy(sct => sct.Position)
                        .Select(sct => sct.Trick!.Abbreviation));
                    return $"[{ct.SubCombo.Name}: {inner}]";
                }
            })),
            AiDescription = c.AiDescription,
            Tricks = c.ComboTricks.OrderBy(ct => ct.Position).Select(ct =>
            {
                if (ct.TrickId.HasValue)
                    return new ComboTrickDto
                    {
                        Type = "trick",
                        TrickId = ct.TrickId,
                        Name = ct.Trick!.Name,
                        Abbreviation = ct.Trick.Abbreviation,
                        Position = ct.Position,
                        StrongFoot = ct.StrongFoot,
                        NoTouch = ct.NoTouch,
                        Difficulty = ct.Trick.Difficulty,
                        Revolution = ct.Trick.Revolution,
                        CrossOver = ct.Trick.CrossOver,
                        IsTransition = ct.Trick.IsTransition
                    };
                else
                    return new ComboTrickDto
                    {
                        Type = "combo",
                        SubComboId = ct.SubComboId,
                        SubComboName = ct.SubCombo?.Name,
                        Position = ct.Position,
                        SubComboTricks = ct.SubCombo?.ComboTricks
                            .Where(sct => sct.TrickId.HasValue)
                            .OrderBy(sct => sct.Position)
                            .Select(sct => new ComboTrickDto
                            {
                                Type = "trick",
                                TrickId = sct.TrickId,
                                Name = sct.Trick!.Name,
                                Abbreviation = sct.Trick.Abbreviation,
                                Position = sct.Position,
                                Difficulty = sct.Trick.Difficulty,
                                Revolution = sct.Trick.Revolution,
                                CrossOver = sct.Trick.CrossOver,
                                IsTransition = sct.Trick.IsTransition,
                                StrongFoot = sct.StrongFoot,
                                NoTouch = sct.NoTouch
                            }).ToList()
                    };
            }).ToList(),
            AverageRating = c.Ratings.Any() ? Math.Round(c.Ratings.Average(r => r.Score), 2) : 0,
            TotalRatings = c.Ratings.Count,
            IsFavourited = true,
            IsCompleted = completedIds.Contains(c.Id),
            CompletionCount = completionCounts.GetValueOrDefault(c.Id, 0),
            IsReusable = c.IsReusable
        }).ToList();
    }
}
