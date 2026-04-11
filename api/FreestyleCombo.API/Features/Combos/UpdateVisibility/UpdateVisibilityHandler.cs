using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.UpdateVisibility;

public class UpdateVisibilityHandler : IRequestHandler<UpdateVisibilityCommand>
{
    private readonly IComboRepository _repo;

    public UpdateVisibilityHandler(IComboRepository repo) => _repo = repo;

    public async Task Handle(UpdateVisibilityCommand request, CancellationToken cancellationToken)
    {
        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (combo.OwnerId != request.UserId)
            throw new UnauthorizedAccessException("You do not own this combo.");

        combo.Visibility = request.IsPublic ? ComboVisibility.PendingReview : ComboVisibility.Private;
        await _repo.UpdateAsync(combo, cancellationToken);
    }
}
