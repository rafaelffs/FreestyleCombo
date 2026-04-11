using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Repositories;

public class UserComboCompletionRepository : IUserComboCompletionRepository
{
    private readonly AppDbContext _db;

    public UserComboCompletionRepository(AppDbContext db) => _db = db;

    public async Task AddAsync(Guid userId, Guid comboId, CancellationToken ct = default)
    {
        if (!await _db.Combos.AnyAsync(c => c.Id == comboId, ct))
            throw new KeyNotFoundException("Combo not found.");

        if (!await ExistsAsync(userId, comboId, ct))
        {
            await _db.UserComboCompletions.AddAsync(new UserComboCompletion
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
        var completion = await _db.UserComboCompletions
            .FirstOrDefaultAsync(c => c.UserId == userId && c.ComboId == comboId, ct);
        if (completion != null)
        {
            _db.UserComboCompletions.Remove(completion);
            await _db.SaveChangesAsync(ct);
        }
    }

    public async Task<HashSet<Guid>> GetCompletedComboIdsAsync(Guid userId, CancellationToken ct = default) =>
        (await _db.UserComboCompletions
            .Where(c => c.UserId == userId)
            .Select(c => c.ComboId)
            .ToListAsync(ct))
        .ToHashSet();

    public async Task<bool> ExistsAsync(Guid userId, Guid comboId, CancellationToken ct = default) =>
        await _db.UserComboCompletions
            .AnyAsync(c => c.UserId == userId && c.ComboId == comboId, ct);

    public async Task<Dictionary<Guid, int>> GetCompletionCountsAsync(IEnumerable<Guid> comboIds, CancellationToken ct = default)
    {
        var ids = comboIds.ToList();
        return await _db.UserComboCompletions
            .Where(c => ids.Contains(c.ComboId))
            .GroupBy(c => c.ComboId)
            .Select(g => new { ComboId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.ComboId, x => x.Count, ct);
    }
}
