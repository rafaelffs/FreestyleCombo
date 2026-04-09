using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.Combos.GetCombo;

public class GetComboHandler : IRequestHandler<GetComboQuery, ComboDetailDto>
{
    private readonly IComboRepository _repo;

    public GetComboHandler(IComboRepository repo) => _repo = repo;

    public async Task<ComboDetailDto> Handle(GetComboQuery request, CancellationToken cancellationToken)
    {
        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (!combo.IsPublic && combo.OwnerId != request.RequestingUserId)
            throw new UnauthorizedAccessException("Access denied.");

        var displayText = string.Join(" ", combo.ComboTricks
            .OrderBy(ct => ct.Position)
            .Select(ct => ct.NoTouch ? $"{ct.Trick.Abbreviation}(nt)" : ct.Trick.Abbreviation));

        var avgRating = combo.Ratings.Any() ? combo.Ratings.Average(r => r.Score) : 0;

        return new ComboDetailDto
        {
            Id = combo.Id,
            OwnerId = combo.OwnerId,
            TotalDifficulty = combo.TotalDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = combo.AiDescription,
            AverageRating = Math.Round(avgRating, 2),
            TotalRatings = combo.Ratings.Count,
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
