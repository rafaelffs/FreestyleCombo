using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Repositories;

public class ComboRatingRepository : IComboRatingRepository
{
    private readonly AppDbContext _db;

    public ComboRatingRepository(AppDbContext db) => _db = db;

    public async Task<ComboRating?> GetByComboAndUserAsync(Guid comboId, Guid userId, CancellationToken ct = default) =>
        await _db.ComboRatings.FirstOrDefaultAsync(r => r.ComboId == comboId && r.RatedByUserId == userId, ct);

    public async Task<(double Average, int Total, Dictionary<int, int> Distribution)> GetStatsAsync(Guid comboId, CancellationToken ct = default)
    {
        var ratings = await _db.ComboRatings.Where(r => r.ComboId == comboId).ToListAsync(ct);
        var total = ratings.Count;
        var average = total > 0 ? ratings.Average(r => r.Score) : 0;
        var distribution = Enumerable.Range(1, 5).ToDictionary(i => i, i => ratings.Count(r => r.Score == i));
        return (average, total, distribution);
    }

    public async Task AddAsync(ComboRating rating, CancellationToken ct = default)
    {
        await _db.ComboRatings.AddAsync(rating, ct);
        await _db.SaveChangesAsync(ct);
    }

    public async Task<List<ComboRating>> GetByComboAsync(Guid comboId, CancellationToken ct = default) =>
        await _db.ComboRatings.Where(r => r.ComboId == comboId).ToListAsync(ct);
}
