using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.AddFavourite;

public class AddFavouriteHandler : IRequestHandler<AddFavouriteCommand>
{
    private readonly IUserFavouriteRepository _favRepo;

    public AddFavouriteHandler(IUserFavouriteRepository favRepo) => _favRepo = favRepo;

    public async Task Handle(AddFavouriteCommand request, CancellationToken cancellationToken) =>
        await _favRepo.AddAsync(request.UserId, request.ComboId, cancellationToken);
}
