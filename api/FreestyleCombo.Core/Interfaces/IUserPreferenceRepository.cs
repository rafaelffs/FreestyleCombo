using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Core.Interfaces;

public interface IUserPreferenceRepository
{
    Task<List<UserPreference>> GetAllByUserIdAsync(Guid userId, CancellationToken ct = default);
    Task<UserPreference?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task AddAsync(UserPreference preference, CancellationToken ct = default);
    Task UpdateAsync(UserPreference preference, CancellationToken ct = default);
    Task DeleteAsync(UserPreference preference, CancellationToken ct = default);
}
