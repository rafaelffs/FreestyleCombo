namespace FreestyleCombo.Core.Interfaces;

public interface IUserFavouriteRepository
{
    Task AddAsync(Guid userId, Guid comboId, CancellationToken ct = default);
    Task RemoveAsync(Guid userId, Guid comboId, CancellationToken ct = default);
    Task<HashSet<Guid>> GetFavouriteComboIdsAsync(Guid userId, CancellationToken ct = default);
    Task<bool> ExistsAsync(Guid userId, Guid comboId, CancellationToken ct = default);
}
