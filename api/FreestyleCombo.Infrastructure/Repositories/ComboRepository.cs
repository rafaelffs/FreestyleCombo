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

    public async Task<(List<Combo> Items, int TotalCount)> GetPublicAsync(int page, int pageSize, string? sortBy, int? maxDifficulty, string? search, CancellationToken ct = default)
    {
        var query = _db.Combos
            .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
            .Include(c => c.Ratings)
            .Include(c => c.Owner)
            .Where(c => c.Visibility == ComboVisibility.Public);

        if (maxDifficulty.HasValue)
            query = query.Where(c => c.AverageDifficulty <= maxDifficulty.Value);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(c =>
                (c.Name != null && c.Name.ToLower().Contains(term)) ||
                (c.Owner != null && c.Owner.UserName != null && c.Owner.UserName.ToLower().Contains(term)) ||
                c.ComboTricks.Any(ct2 => ct2.Trick.Abbreviation.ToLower().Contains(term)));
        }

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
            query = isPublic.Value
                ? query.Where(c => c.Visibility != ComboVisibility.Private)
                : query.Where(c => c.Visibility == ComboVisibility.Private);

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
            query = isPublic.Value
                ? query.Where(c => c.Visibility != ComboVisibility.Private)
                : query.Where(c => c.Visibility == ComboVisibility.Private);

        return await query.ToListAsync(ct);
    }

    public async Task<List<Combo>> GetFavouritedByUserAsync(Guid userId, CancellationToken ct = default) =>
        await _db.Combos
            .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
            .Include(c => c.Ratings)
            .Include(c => c.Owner)
            .Where(c => c.FavouritedBy.Any(f => f.UserId == userId))
            .OrderByDescending(c => c.FavouritedBy.First(f => f.UserId == userId).CreatedAt)
            .ToListAsync(ct);

    public async Task<int> GetPendingReviewCountAsync(CancellationToken ct = default) =>
        await _db.Combos.CountAsync(c => c.Visibility == ComboVisibility.PendingReview, ct);

    public async Task<List<Combo>> GetPendingReviewAsync(CancellationToken ct = default) =>
        await _db.Combos
            .Include(c => c.ComboTricks).ThenInclude(ct2 => ct2.Trick)
            .Include(c => c.Ratings)
            .Include(c => c.Owner)
            .Where(c => c.Visibility == ComboVisibility.PendingReview)
            .OrderBy(c => c.CreatedAt)
            .ToListAsync(ct);

    public async Task AddAsync(Combo combo, CancellationToken ct = default)
    {
        await _db.Combos.AddAsync(combo, ct);
        await _db.SaveChangesAsync(ct);
    }

    public async Task UpdateAsync(Combo combo, CancellationToken ct = default)
    {
        // If the entity is already tracked (common in handlers that load then mutate),
        // calling Update on the full graph can cause state conflicts with child collections.
        var isTracked = _db.ChangeTracker.Entries<Combo>().Any(e => e.Entity.Id == combo.Id);
        if (!isTracked)
            _db.Combos.Update(combo);

        await _db.SaveChangesAsync(ct);
    }

    public async Task ReplaceComboTricksAsync(Guid comboId, IEnumerable<ComboTrick> newTricks, CancellationToken ct = default)
    {
        var existing = await _db.ComboTricks.Where(t => t.ComboId == comboId).ToListAsync(ct);
        _db.ComboTricks.RemoveRange(existing);
        _db.ComboTricks.AddRange(newTricks);
        // SaveChanges is deferred — caller must invoke UpdateAsync to persist atomically.
    }

    public async Task DeleteAsync(Guid id, CancellationToken ct = default)
    {
        var combo = await _db.Combos.FindAsync([id], ct)
            ?? throw new KeyNotFoundException("Combo not found.");
        _db.Combos.Remove(combo);
        await _db.SaveChangesAsync(ct);
    }
}
