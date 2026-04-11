using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Core.Interfaces;

public interface IComboRepository
{
    Task<Combo?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<(List<Combo> Items, int TotalCount)> GetPublicAsync(int page, int pageSize, string? sortBy, int? maxDifficulty, CancellationToken ct = default);
    Task<(List<Combo> Items, int TotalCount)> GetByOwnerAsync(Guid ownerId, int page, int pageSize, bool? isPublic, CancellationToken ct = default);
    Task<List<Combo>> GetAllByOwnerAsync(Guid ownerId, bool? isPublic, CancellationToken ct = default);
    Task<List<Combo>> GetFavouritedByUserAsync(Guid userId, CancellationToken ct = default);
    Task<List<Combo>> GetPendingReviewAsync(CancellationToken ct = default);
    Task<int> GetPendingReviewCountAsync(CancellationToken ct = default);
    Task AddAsync(Combo combo, CancellationToken ct = default);
    Task UpdateAsync(Combo combo, CancellationToken ct = default);
    Task ReplaceComboTricksAsync(Guid comboId, IEnumerable<ComboTrick> newTricks, CancellationToken ct = default);
    Task DeleteAsync(Guid id, CancellationToken ct = default);
}
