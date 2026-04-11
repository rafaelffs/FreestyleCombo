using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.RejectComboVisibility;

public class RejectComboVisibilityHandler : IRequestHandler<RejectComboVisibilityCommand>
{
    private readonly IComboRepository _repo;

    public RejectComboVisibilityHandler(IComboRepository repo) => _repo = repo;

    public async Task Handle(RejectComboVisibilityCommand request, CancellationToken cancellationToken)
    {
        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (combo.Visibility != ComboVisibility.PendingReview)
            throw new InvalidOperationException("Only combos pending review can be rejected.");

        combo.Visibility = ComboVisibility.Private;
        await _repo.UpdateAsync(combo, cancellationToken);
    }
}
