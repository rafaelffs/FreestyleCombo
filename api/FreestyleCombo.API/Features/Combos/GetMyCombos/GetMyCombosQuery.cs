using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetMyCombos;

public record GetMyCombosQuery(Guid UserId, int Page, int PageSize, bool? IsPublic) : IRequest<PagedResult<MyComboDto>>;

public class MyComboDto
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public double AverageDifficulty { get; set; }
    public int TrickCount { get; set; }
    public bool IsPublic { get; set; }
    public DateTime CreatedAt { get; set; }
    public string DisplayText { get; set; } = string.Empty;
    public string? AiDescription { get; set; }
    public List<ComboTrickDto> Tricks { get; set; } = [];
    public double AverageRating { get; set; }
    public int TotalRatings { get; set; }
}
