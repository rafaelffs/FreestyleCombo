using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Core.Interfaces;

public interface ITrickRepository
{
    Task<List<Trick>> GetAllAsync(bool? crossOver = null, bool? knee = null, int? maxDifficulty = null, CancellationToken ct = default);
    Task<Trick?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task AddAsync(Trick trick, CancellationToken ct = default);
    Task UpdateAsync(Trick trick, CancellationToken ct = default);
    Task<bool> IsEmptyAsync(CancellationToken ct = default);
}
