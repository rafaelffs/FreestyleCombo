using MediatR;

namespace FreestyleCombo.API.Features.Combos.RemoveFavourite;

public record RemoveFavouriteCommand(Guid ComboId, Guid UserId) : IRequest;
