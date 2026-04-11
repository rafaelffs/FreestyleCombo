using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.ApproveComboVisibility;

public class ApproveComboVisibilityHandler : IRequestHandler<ApproveComboVisibilityCommand>
{
    private readonly IComboRepository _repo;

    public ApproveComboVisibilityHandler(IComboRepository repo) => _repo = repo;

    public async Task Handle(ApproveComboVisibilityCommand request, CancellationToken cancellationToken)
    {
        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (combo.Visibility != ComboVisibility.PendingReview)
            throw new InvalidOperationException("Only combos pending review can be approved.");

        combo.Visibility = ComboVisibility.Public;
        await _repo.UpdateAsync(combo, cancellationToken);
    }
}
