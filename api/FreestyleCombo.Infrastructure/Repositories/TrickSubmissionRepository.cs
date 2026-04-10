using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Repositories;

public class TrickSubmissionRepository : ITrickSubmissionRepository
{
    private readonly AppDbContext _db;

    public TrickSubmissionRepository(AppDbContext db) => _db = db;

    public async Task AddAsync(TrickSubmission submission, CancellationToken ct = default)
    {
        await _db.TrickSubmissions.AddAsync(submission, ct);
        await _db.SaveChangesAsync(ct);
    }

    public async Task<TrickSubmission?> GetByIdAsync(Guid id, CancellationToken ct = default) =>
        await _db.TrickSubmissions.FindAsync([id], ct);

    public async Task<List<TrickSubmission>> GetPendingAsync(CancellationToken ct = default) =>
        await _db.TrickSubmissions
            .Where(s => s.Status == SubmissionStatus.Pending)
            .Include(s => s.SubmittedBy)
            .OrderBy(s => s.SubmittedAt)
            .ToListAsync(ct);

    public async Task<List<TrickSubmission>> GetByUserIdAsync(Guid userId, CancellationToken ct = default) =>
        await _db.TrickSubmissions
            .Where(s => s.SubmittedById == userId)
            .OrderByDescending(s => s.SubmittedAt)
            .ToListAsync(ct);

    public async Task UpdateAsync(TrickSubmission submission, CancellationToken ct = default)
    {
        _db.TrickSubmissions.Update(submission);
        await _db.SaveChangesAsync(ct);
    }
}
