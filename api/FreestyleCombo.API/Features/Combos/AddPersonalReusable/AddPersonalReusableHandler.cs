using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.AddPersonalReusable;

public class AddPersonalReusableHandler : IRequestHandler<AddPersonalReusableCommand>
{
    private readonly IComboRepository _comboRepo;
    private readonly IUserPersonalReusableComboRepository _personalReusableRepo;

    public AddPersonalReusableHandler(IComboRepository comboRepo, IUserPersonalReusableComboRepository personalReusableRepo)
    {
        _comboRepo = comboRepo;
        _personalReusableRepo = personalReusableRepo;
    }

    public async Task Handle(AddPersonalReusableCommand request, CancellationToken cancellationToken)
    {
        var combo = await _comboRepo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        // Owners can list any of their own combos, at any visibility. Anyone
        // else can only list a combo that's actually Public — this is a
        // per-user bookmark into your own trick-building list, not a way to
        // peek at combos you otherwise couldn't see.
        if (combo.OwnerId != request.UserId && combo.Visibility != ComboVisibility.Public)
            throw new UnauthorizedAccessException("You can only list your own combos or public combos.");

        await _personalReusableRepo.AddAsync(request.UserId, request.ComboId, cancellationToken);
    }
}
