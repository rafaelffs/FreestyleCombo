using MediatR;

namespace FreestyleCombo.API.Features.Combos.AddFavourite;

public record AddFavouriteCommand(Guid ComboId, Guid UserId) : IRequest;
