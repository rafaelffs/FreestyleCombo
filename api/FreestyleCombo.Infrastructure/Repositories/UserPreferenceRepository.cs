using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Repositories;

public class UserPreferenceRepository : IUserPreferenceRepository
{
    private readonly AppDbContext _db;

    public UserPreferenceRepository(AppDbContext db) => _db = db;

    public async Task<UserPreference?> GetByUserIdAsync(Guid userId, CancellationToken ct = default) =>
        await _db.UserPreferences.FirstOrDefaultAsync(p => p.UserId == userId, ct);

    public async Task AddAsync(UserPreference preference, CancellationToken ct = default)
    {
        await _db.UserPreferences.AddAsync(preference, ct);
        await _db.SaveChangesAsync(ct);
    }

    public async Task UpdateAsync(UserPreference preference, CancellationToken ct = default)
    {
        _db.UserPreferences.Update(preference);
        await _db.SaveChangesAsync(ct);
    }
}
