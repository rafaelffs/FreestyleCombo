using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Repositories;

public class ComboRepository : IComboRepository
{
    private readonly AppDbContext _db;

    public ComboRepository(AppDbContext db) => _db = db;

    public async Task<Combo?> GetByIdAsync(Guid id, CancellationToken ct = default) =>
        await _db.Combos
            .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
            .Include(c => c.Ratings)
            .Include(c => c.Owner)
            .FirstOrDefaultAsync(c => c.Id == id, ct);

    public async Task<(List<Combo> Items, int TotalCount)> GetPublicAsync(int page, int pageSize, string? sortBy, int? maxDifficulty, CancellationToken ct = default)
    {
        var query = _db.Combos
            .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
            .Include(c => c.Ratings)
            .Include(c => c.Owner)
            .Where(c => c.IsPublic);

        if (maxDifficulty.HasValue)
            query = query.Where(c => c.AverageDifficulty <= maxDifficulty.Value);

        query = sortBy switch
        {
            "difficulty" => query.OrderByDescending(c => c.AverageDifficulty),
            "rating" => query.OrderByDescending(c => c.Ratings.Any() ? c.Ratings.Average(r => r.Score) : 0),
            _ => query.OrderByDescending(c => c.CreatedAt)
        };

        var total = await query.CountAsync(ct);
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return (items, total);
    }

    public async Task<(List<Combo> Items, int TotalCount)> GetByOwnerAsync(Guid ownerId, int page, int pageSize, bool? isPublic, CancellationToken ct = default)
    {
        var query = _db.Combos
            .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
            .Include(c => c.Ratings)
            .Include(c => c.Owner)
            .Where(c => c.OwnerId == ownerId);

        if (isPublic.HasValue)
            query = query.Where(c => c.IsPublic == isPublic.Value);

        query = query.OrderByDescending(c => c.CreatedAt);

        var total = await query.CountAsync(ct);
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return (items, total);
    }

    public async Task<List<Combo>> GetAllByOwnerAsync(Guid ownerId, bool? isPublic, CancellationToken ct = default)
    {
        var query = _db.Combos
            .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
            .Include(c => c.Ratings)
            .Include(c => c.Owner)
            .Where(c => c.OwnerId == ownerId);

        if (isPublic.HasValue)
            query = query.Where(c => c.IsPublic == isPublic.Value);

        return await query.ToListAsync(ct);
    }

    public async Task AddAsync(Combo combo, CancellationToken ct = default)
    {
        await _db.Combos.AddAsync(combo, ct);
        await _db.SaveChangesAsync(ct);
    }

    public async Task UpdateAsync(Combo combo, CancellationToken ct = default)
    {
        _db.Combos.Update(combo);
        await _db.SaveChangesAsync(ct);
    }

    public async Task DeleteAsync(Guid id, CancellationToken ct = default)
    {
        var combo = await _db.Combos.FindAsync([id], ct)
            ?? throw new KeyNotFoundException("Combo not found.");
        _db.Combos.Remove(combo);
        await _db.SaveChangesAsync(ct);
    }
}
