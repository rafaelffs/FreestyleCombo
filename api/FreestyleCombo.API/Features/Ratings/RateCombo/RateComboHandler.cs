using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Ratings.RateCombo;

public class RateComboHandler : IRequestHandler<RateComboCommand, Guid>
{
    private readonly IComboRepository _comboRepo;
    private readonly IComboRatingRepository _ratingRepo;

    public RateComboHandler(IComboRepository comboRepo, IComboRatingRepository ratingRepo)
    {
        _comboRepo = comboRepo;
        _ratingRepo = ratingRepo;
    }

    public async Task<Guid> Handle(RateComboCommand request, CancellationToken cancellationToken)
    {
        var combo = await _comboRepo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (!combo.IsPublic)
            throw new UnauthorizedAccessException("Cannot rate a private combo.");

        if (combo.OwnerId == request.UserId)
            throw new InvalidOperationException("You cannot rate your own combo.");

        var existing = await _ratingRepo.GetByComboAndUserAsync(request.ComboId, request.UserId, cancellationToken);
        if (existing != null)
        {
            existing.Score = request.Score;
            await _ratingRepo.UpdateAsync(existing, cancellationToken);
            return existing.Id;
        }

        var rating = new ComboRating
        {
            Id = Guid.NewGuid(),
            ComboId = request.ComboId,
            RatedByUserId = request.UserId,
            Score = request.Score,
            CreatedAt = DateTime.UtcNow
        };

        await _ratingRepo.AddAsync(rating, cancellationToken);
        return rating.Id;
    }
}
