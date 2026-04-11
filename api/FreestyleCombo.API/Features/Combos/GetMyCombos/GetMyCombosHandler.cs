using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetMyCombos;

public class GetMyCombosHandler : IRequestHandler<GetMyCombosQuery, PagedResult<MyComboDto>>
{
    private readonly IComboRepository _repo;
    private readonly IUserFavouriteRepository _favRepo;
    private readonly IUserComboCompletionRepository _completionRepo;

    public GetMyCombosHandler(IComboRepository repo, IUserFavouriteRepository favRepo, IUserComboCompletionRepository completionRepo)
    {
        _repo = repo;
        _favRepo = favRepo;
        _completionRepo = completionRepo;
    }

    public async Task<PagedResult<MyComboDto>> Handle(GetMyCombosQuery request, CancellationToken cancellationToken)
    {
        var allCombos = await _repo.GetAllByOwnerAsync(request.UserId, request.IsPublic, cancellationToken);
        var favIds = await _favRepo.GetFavouriteComboIdsAsync(request.UserId, cancellationToken);
        var completedIds = await _completionRepo.GetCompletedComboIdsAsync(request.UserId, cancellationToken);

        var sorted = allCombos
            .OrderByDescending(c => c.CreatedAt)
            .ToList();

        var total = sorted.Count;
        var items = sorted
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToList();

        var completionCounts = await _completionRepo.GetCompletionCountsAsync(items.Select(c => c.Id), cancellationToken);

        return new PagedResult<MyComboDto>
        {
            TotalCount = total,
            Page = request.Page,
            PageSize = request.PageSize,
            Items = items.Select(c => new MyComboDto
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
                IsFavourited = favIds.Contains(c.Id),
                IsCompleted = completedIds.Contains(c.Id),
                CompletionCount = completionCounts.GetValueOrDefault(c.Id, 0)
            }).ToList()
        };
    }
}
