using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Ratings.GetRatings;

public class GetRatingsHandler : IRequestHandler<GetRatingsQuery, RatingsStatsDto>
{
    private readonly IComboRatingRepository _repo;

    public GetRatingsHandler(IComboRatingRepository repo) => _repo = repo;

    public async Task<RatingsStatsDto> Handle(GetRatingsQuery request, CancellationToken cancellationToken)
    {
        var (average, total, distribution) = await _repo.GetStatsAsync(request.ComboId, cancellationToken);
        return new RatingsStatsDto
        {
            AverageScore = Math.Round(average, 2),
            TotalCount = total,
            Distribution = distribution
        };
    }
}
