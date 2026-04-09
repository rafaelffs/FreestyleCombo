using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Core.Interfaces;

public interface IComboRepository
{
    Task<Combo?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<(List<Combo> Items, int TotalCount)> GetPublicAsync(int page, int pageSize, string? sortBy, int? maxDifficulty, CancellationToken ct = default);
    Task<(List<Combo> Items, int TotalCount)> GetByOwnerAsync(Guid ownerId, int page, int pageSize, bool? isPublic, CancellationToken ct = default);
    Task AddAsync(Combo combo, CancellationToken ct = default);
    Task UpdateAsync(Combo combo, CancellationToken ct = default);
}
