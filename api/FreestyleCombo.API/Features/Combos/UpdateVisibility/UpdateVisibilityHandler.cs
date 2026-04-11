using System.Security.Claims;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.Combos.UpdateVisibility;

public class UpdateVisibilityHandler : IRequestHandler<UpdateVisibilityCommand>
{
    private readonly IComboRepository _repo;
    private readonly IHttpContextAccessor _http;

    public UpdateVisibilityHandler(IComboRepository repo, IHttpContextAccessor http)
    {
        _repo = repo;
        _http = http;
    }

    public async Task Handle(UpdateVisibilityCommand request, CancellationToken cancellationToken)
    {
        var isAdmin = _http.HttpContext!.User.IsInRole("Admin");

        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (combo.OwnerId != request.UserId && !isAdmin)
            throw new UnauthorizedAccessException("You do not own this combo.");

        if (request.IsPublic)
        {
            combo.Visibility = isAdmin ? ComboVisibility.Public : ComboVisibility.PendingReview;
        }
        else
        {
            // Only admins can remove a combo that is already Public
            if (combo.Visibility == ComboVisibility.Public && !isAdmin)
                throw new UnauthorizedAccessException("Only admins can make a public combo private.");

            combo.Visibility = ComboVisibility.Private;
        }

        await _repo.UpdateAsync(combo, cancellationToken);
    }
}
