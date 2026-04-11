using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetPendingComboReviews;

public record GetPendingComboReviewsQuery : IRequest<List<PublicComboDto>>;
