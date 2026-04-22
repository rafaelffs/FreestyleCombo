using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Interfaces;
using MediatR;


namespace FreestyleCombo.API.Features.Combos.GetPublicCombos;

public class GetPublicCombosHandler : IRequestHandler<GetPublicCombosQuery, PagedResult<PublicComboDto>>
{
    private readonly IComboRepository _repo;
    private readonly IUserFavouriteRepository _favRepo;
    private readonly IUserComboCompletionRepository _completionRepo;

    public GetPublicCombosHandler(IComboRepository repo, IUserFavouriteRepository favRepo, IUserComboCompletionRepository completionRepo)
    {
        _repo = repo;
        _favRepo = favRepo;
        _completionRepo = completionRepo;
    }

    public async Task<PagedResult<PublicComboDto>> Handle(GetPublicCombosQuery request, CancellationToken cancellationToken)
    {
        var (items, total) = await _repo.GetPublicAsync(request.Page, request.PageSize, request.SortBy, request.MaxDifficulty, cancellationToken);

        var favIds = request.RequestingUserId.HasValue
            ? await _favRepo.GetFavouriteComboIdsAsync(request.RequestingUserId.Value, cancellationToken)
            : [];

        var comboIds = items.Select(c => c.Id);
        var completedIds = request.RequestingUserId.HasValue
            ? await _completionRepo.GetCompletedComboIdsAsync(request.RequestingUserId.Value, cancellationToken)
            : [];
        var completionCounts = await _completionRepo.GetCompletionCountsAsync(comboIds, cancellationToken);

        return new PagedResult<PublicComboDto>
        {
            TotalCount = total,
            Page = request.Page,
            PageSize = request.PageSize,
            Items = items.Select(c => new PublicComboDto
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
                    Revolution = ct.Trick.Revolution,
                    CrossOver = ct.Trick.CrossOver,
                    IsTransition = ct.Trick.IsTransition
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
