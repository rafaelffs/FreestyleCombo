using MediatR;

namespace FreestyleCombo.API.Features.Ratings.GetRatings;

public record GetRatingsQuery(Guid ComboId) : IRequest<RatingsStatsDto>;

public class RatingsStatsDto
{
    public double AverageScore { get; set; }
    public int TotalCount { get; set; }
    public Dictionary<int, int> Distribution { get; set; } = [];
}
