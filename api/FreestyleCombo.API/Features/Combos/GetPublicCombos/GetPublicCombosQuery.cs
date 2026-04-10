using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetPublicCombos;

public record GetPublicCombosQuery(int Page, int PageSize, string? SortBy, int? MaxDifficulty, Guid? RequestingUserId = null) : IRequest<PagedResult<PublicComboDto>>;

public class PagedResult<T>
{
    public List<T> Items { get; set; } = [];
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
}
