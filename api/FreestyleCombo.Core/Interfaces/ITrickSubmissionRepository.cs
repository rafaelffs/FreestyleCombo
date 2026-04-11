using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Core.Interfaces;

public interface ITrickSubmissionRepository
{
    Task AddAsync(TrickSubmission submission, CancellationToken ct = default);
    Task<TrickSubmission?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<List<TrickSubmission>> GetPendingAsync(CancellationToken ct = default);
    Task<int> GetPendingCountAsync(CancellationToken ct = default);
    Task<List<TrickSubmission>> GetByUserIdAsync(Guid userId, CancellationToken ct = default);
    Task UpdateAsync(TrickSubmission submission, CancellationToken ct = default);
}
