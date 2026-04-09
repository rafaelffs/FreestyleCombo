using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Core.Interfaces;

public interface IUserPreferenceRepository
{
    Task<UserPreference?> GetByUserIdAsync(Guid userId, CancellationToken ct = default);
    Task AddAsync(UserPreference preference, CancellationToken ct = default);
    Task UpdateAsync(UserPreference preference, CancellationToken ct = default);
}
