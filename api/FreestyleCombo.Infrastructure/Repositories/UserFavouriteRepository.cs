using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Repositories;

public class UserFavouriteRepository : IUserFavouriteRepository
{
    private readonly AppDbContext _db;

    public UserFavouriteRepository(AppDbContext db) => _db = db;

    public async Task AddAsync(Guid userId, Guid comboId, CancellationToken ct = default)
    {
        if (!await _db.Combos.AnyAsync(c => c.Id == comboId, ct))
            throw new KeyNotFoundException("Combo not found.");

        if (!await ExistsAsync(userId, comboId, ct))
        {
            await _db.UserFavouriteCombos.AddAsync(new UserFavouriteCombo
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
        var fav = await _db.UserFavouriteCombos
            .FirstOrDefaultAsync(f => f.UserId == userId && f.ComboId == comboId, ct);
        if (fav != null)
        {
            _db.UserFavouriteCombos.Remove(fav);
            await _db.SaveChangesAsync(ct);
        }
    }

    public async Task<HashSet<Guid>> GetFavouriteComboIdsAsync(Guid userId, CancellationToken ct = default) =>
        (await _db.UserFavouriteCombos
            .Where(f => f.UserId == userId)
            .Select(f => f.ComboId)
            .ToListAsync(ct))
        .ToHashSet();

    public async Task<bool> ExistsAsync(Guid userId, Guid comboId, CancellationToken ct = default) =>
        await _db.UserFavouriteCombos
            .AnyAsync(f => f.UserId == userId && f.ComboId == comboId, ct);
}
