using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Repositories;

public class UserPersonalReusableComboRepository : IUserPersonalReusableComboRepository
{
    private readonly AppDbContext _db;

    public UserPersonalReusableComboRepository(AppDbContext db) => _db = db;

    public async Task AddAsync(Guid userId, Guid comboId, CancellationToken ct = default)
    {
        if (!await _db.Combos.AnyAsync(c => c.Id == comboId, ct))
            throw new KeyNotFoundException("Combo not found.");

        if (!await ExistsAsync(userId, comboId, ct))
        {
            await _db.UserPersonalReusableCombos.AddAsync(new UserPersonalReusableCombo
            {
                UserId = userId,
                ComboId = comboId,
                CreatedAt = DateTime.UtcNow
            }, ct);
            await _db.SaveChangesAsync(ct);
        }
    }

    public async Task RemoveAsync(Guid userId, Guid comboId, CancellationToken ct = default)
    {
        var entry = await _db.UserPersonalReusableCombos
            .FirstOrDefaultAsync(f => f.UserId == userId && f.ComboId == comboId, ct);
        if (entry != null)
        {
            _db.UserPersonalReusableCombos.Remove(entry);
            await _db.SaveChangesAsync(ct);
        }
    }

    public async Task<HashSet<Guid>> GetComboIdsAsync(Guid userId, CancellationToken ct = default) =>
        (await _db.UserPersonalReusableCombos
            .Where(f => f.UserId == userId)
            .Select(f => f.ComboId)
            .ToListAsync(ct))
        .ToHashSet();

    public async Task<bool> ExistsAsync(Guid userId, Guid comboId, CancellationToken ct = default) =>
        await _db.UserPersonalReusableCombos
            .AnyAsync(f => f.UserId == userId && f.ComboId == comboId, ct);
}
