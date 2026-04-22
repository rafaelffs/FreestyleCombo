using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetPendingComboReviews;

public class GetPendingComboReviewsHandler : IRequestHandler<GetPendingComboReviewsQuery, List<PublicComboDto>>
{
    private readonly IComboRepository _repo;

    public GetPendingComboReviewsHandler(IComboRepository repo) => _repo = repo;

    public async Task<List<PublicComboDto>> Handle(GetPendingComboReviewsQuery request, CancellationToken cancellationToken)
    {
        var combos = await _repo.GetPendingReviewAsync(cancellationToken);

        return combos.Select(c => new PublicComboDto
        {
            Id = c.Id,
            OwnerId = c.OwnerId,
            OwnerUserName = c.Owner?.UserName,
            Name = c.Name,
            AverageDifficulty = c.AverageDifficulty,
            TrickCount = c.TrickCount,
            IsPublic = c.IsPublic,
            Visibility = c.Visibility.ToString(),
            CreatedAt = c.CreatedAt,
            DisplayText = string.Join(" ", c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => ct.NoTouch ? $"{ct.Trick.Abbreviation}(nt)" : ct.Trick.Abbreviation)),
            AiDescription = c.AiDescription,
            Tricks = c.ComboTricks.OrderBy(ct => ct.Position).Select(ct => new ComboTrickDto
            {
                TrickId = ct.TrickId,
                Name = ct.Trick.Name,
                Abbreviation = ct.Trick.Abbreviation,
                Position = ct.Position,
                StrongFoot = ct.StrongFoot,
                NoTouch = ct.NoTouch,
                Difficulty = ct.Trick.Difficulty,
                Revolution = ct.Trick.Revolution,
                CrossOver = ct.Trick.CrossOver,
                IsTransition = ct.Trick.IsTransition
            }).ToList(),
            AverageRating = 0,
            TotalRatings = 0,
            IsFavourited = false
        }).ToList();
    }
}
