using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetPublicCombos;

public class GetPublicCombosHandler : IRequestHandler<GetPublicCombosQuery, PagedResult<PublicComboDto>>
{
    private readonly IComboRepository _repo;

    public GetPublicCombosHandler(IComboRepository repo) => _repo = repo;

    public async Task<PagedResult<PublicComboDto>> Handle(GetPublicCombosQuery request, CancellationToken cancellationToken)
    {
        var (items, total) = await _repo.GetPublicAsync(request.Page, request.PageSize, request.SortBy, request.MaxDifficulty, cancellationToken);

        return new PagedResult<PublicComboDto>
        {
            TotalCount = total,
            Page = request.Page,
            PageSize = request.PageSize,
            Items = items.Select(c => new PublicComboDto
            {
                Id = c.Id,
                OwnerId = c.OwnerId,
                TotalDifficulty = c.TotalDifficulty,
                TrickCount = c.TrickCount,
                CreatedAt = c.CreatedAt,
                DisplayText = string.Join(" ", c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => ct.NoTouch ? $"{ct.Trick.Abbreviation}(nt)" : ct.Trick.Abbreviation)),
                AiDescription = c.AiDescription,
                AverageRating = c.Ratings.Any() ? Math.Round(c.Ratings.Average(r => r.Score), 2) : 0,
                TotalRatings = c.Ratings.Count
            }).ToList()
        };
    }
}
