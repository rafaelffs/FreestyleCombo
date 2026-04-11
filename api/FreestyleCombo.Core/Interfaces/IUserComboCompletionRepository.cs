namespace FreestyleCombo.Core.Interfaces;

public interface IUserComboCompletionRepository
{
    Task AddAsync(Guid userId, Guid comboId, CancellationToken ct = default);
    Task RemoveAsync(Guid userId, Guid comboId, CancellationToken ct = default);
    Task<HashSet<Guid>> GetCompletedComboIdsAsync(Guid userId, CancellationToken ct = default);
    Task<bool> ExistsAsync(Guid userId, Guid comboId, CancellationToken ct = default);
    Task<Dictionary<Guid, int>> GetCompletionCountsAsync(IEnumerable<Guid> comboIds, CancellationToken ct = default);
}
