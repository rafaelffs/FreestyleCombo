using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetFavouritedCombos;

public record GetFavouritedCombosQuery(Guid UserId) : IRequest<List<PublicComboDto>>;
