using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.RemoveFavourite;

public class RemoveFavouriteHandler : IRequestHandler<RemoveFavouriteCommand>
{
    private readonly IUserFavouriteRepository _favRepo;

    public RemoveFavouriteHandler(IUserFavouriteRepository favRepo) => _favRepo = favRepo;

    public async Task Handle(RemoveFavouriteCommand request, CancellationToken cancellationToken) =>
        await _favRepo.RemoveAsync(request.UserId, request.ComboId, cancellationToken);
}
