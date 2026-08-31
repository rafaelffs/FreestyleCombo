using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.SetPersonalReusable;

public class SetPersonalReusableHandler : IRequestHandler<SetPersonalReusableCommand>
{
    private readonly IComboRepository _comboRepo;

    public SetPersonalReusableHandler(IComboRepository comboRepo)
    {
        _comboRepo = comboRepo;
    }

    public async Task Handle(SetPersonalReusableCommand request, CancellationToken cancellationToken)
    {
        var combo = await _comboRepo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (combo.OwnerId != request.UserId)
            throw new UnauthorizedAccessException("You do not own this combo.");

        combo.IsPersonalReusable = request.IsPersonalReusable;
        await _comboRepo.UpdateAsync(combo, cancellationToken);
    }
}
