using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Repositories;

public class TrickRepository : ITrickRepository
{
    private readonly AppDbContext _db;

    public TrickRepository(AppDbContext db) => _db = db;

    public async Task<List<Trick>> GetAllAsync(bool? crossOver = null, bool? knee = null, int? maxDifficulty = null, CancellationToken ct = default)
    {
        var query = _db.Tricks.AsQueryable();

        if (crossOver.HasValue)
            query = query.Where(t => t.CrossOver == crossOver.Value);
        if (knee.HasValue)
            query = query.Where(t => t.Knee == knee.Value);
        if (maxDifficulty.HasValue)
            query = query.Where(t => t.Difficulty <= maxDifficulty.Value);

        return await query.ToListAsync(ct);
    }

    public async Task<Trick?> GetByIdAsync(Guid id, CancellationToken ct = default) =>
        await _db.Tricks.FindAsync([id], ct);

    public async Task AddAsync(Trick trick, CancellationToken ct = default)
    {
        await _db.Tricks.AddAsync(trick, ct);
        await _db.SaveChangesAsync(ct);
    }

    public async Task UpdateAsync(Trick trick, CancellationToken ct = default)
    {
        _db.Tricks.Update(trick);
        await _db.SaveChangesAsync(ct);
    }

    public async Task DeleteAsync(Guid id, CancellationToken ct = default)
    {
        var trick = await _db.Tricks
            .Include(t => t.ComboTricks)
            .FirstOrDefaultAsync(t => t.Id == id, ct)
            ?? throw new KeyNotFoundException("Trick not found.");

        if (trick.ComboTricks.Count > 0)
            throw new InvalidOperationException($"This trick is used in {trick.ComboTricks.Count} combo(s) and cannot be deleted.");

        _db.Tricks.Remove(trick);
        await _db.SaveChangesAsync(ct);
    }

    public async Task<bool> IsEmptyAsync(CancellationToken ct = default) =>
        !await _db.Tricks.AnyAsync(ct);
}
