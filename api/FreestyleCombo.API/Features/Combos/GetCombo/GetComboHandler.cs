using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetCombo;

public class GetComboHandler : IRequestHandler<GetComboQuery, ComboDetailDto>
{
    private readonly IComboRepository _repo;
    private readonly IUserFavouriteRepository _favRepo;

    public GetComboHandler(IComboRepository repo, IUserFavouriteRepository favRepo)
    {
        _repo = repo;
        _favRepo = favRepo;
    }

    public async Task<ComboDetailDto> Handle(GetComboQuery request, CancellationToken cancellationToken)
    {
        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (!combo.IsPublic && combo.OwnerId != request.RequestingUserId)
            throw new UnauthorizedAccessException("Access denied.");

        var isFavourited = request.RequestingUserId.HasValue
            && await _favRepo.ExistsAsync(request.RequestingUserId.Value, combo.Id, cancellationToken);

        var displayText = string.Join(" ", combo.ComboTricks
            .OrderBy(ct => ct.Position)
            .Select(ct => ct.NoTouch ? $"{ct.Trick.Abbreviation}(nt)" : ct.Trick.Abbreviation));

        var avgRating = combo.Ratings.Any() ? combo.Ratings.Average(r => r.Score) : 0;

        return new ComboDetailDto
        {
            Id = combo.Id,
            OwnerId = combo.OwnerId,
            OwnerUserName = combo.Owner?.UserName,
            Name = combo.Name,
            AverageDifficulty = combo.AverageDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = combo.AiDescription,
            AverageRating = Math.Round(avgRating, 2),
            TotalRatings = combo.Ratings.Count,
            IsFavourited = isFavourited,
            Tricks = combo.ComboTricks.OrderBy(ct => ct.Position).Select(ct => new ComboTrickDto
            {
                TrickId = ct.TrickId,
                Name = ct.Trick.Name,
                Abbreviation = ct.Trick.Abbreviation,
                Position = ct.Position,
                StrongFoot = ct.StrongFoot,
                NoTouch = ct.NoTouch,
                Difficulty = ct.Trick.Difficulty,
                Motion = ct.Trick.Motion
            }).ToList()
        };
    }
}
