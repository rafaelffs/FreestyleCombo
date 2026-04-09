using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetMyCombos;

public class GetMyCombosHandler : IRequestHandler<GetMyCombosQuery, PagedResult<MyComboDto>>
{
    private readonly IComboRepository _repo;

    public GetMyCombosHandler(IComboRepository repo) => _repo = repo;

    public async Task<PagedResult<MyComboDto>> Handle(GetMyCombosQuery request, CancellationToken cancellationToken)
    {
        var (items, total) = await _repo.GetByOwnerAsync(request.UserId, request.Page, request.PageSize, request.IsPublic, cancellationToken);

        return new PagedResult<MyComboDto>
        {
            TotalCount = total,
            Page = request.Page,
            PageSize = request.PageSize,
            Items = items.Select(c => new MyComboDto
            {
                Id = c.Id,
                TotalDifficulty = c.TotalDifficulty,
                TrickCount = c.TrickCount,
                IsPublic = c.IsPublic,
                CreatedAt = c.CreatedAt,
                DisplayText = string.Join(" ", c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => ct.NoTouch ? $"{ct.Trick.Abbreviation}(nt)" : ct.Trick.Abbreviation)),
                AiDescription = c.AiDescription,
                AverageRating = c.Ratings.Any() ? Math.Round(c.Ratings.Average(r => r.Score), 2) : 0,
                TotalRatings = c.Ratings.Count
            }).ToList()
        };
    }
}
