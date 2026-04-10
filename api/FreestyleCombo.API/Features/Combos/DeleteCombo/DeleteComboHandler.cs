using System.Security.Claims;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.Combos.DeleteCombo;

public class DeleteComboHandler : IRequestHandler<DeleteComboCommand>
{
    private readonly IComboRepository _repo;
    private readonly IHttpContextAccessor _http;

    public DeleteComboHandler(IComboRepository repo, IHttpContextAccessor http)
    {
        _repo = repo;
        _http = http;
    }

    public async Task Handle(DeleteComboCommand request, CancellationToken cancellationToken)
    {
        var user = _http.HttpContext!.User;
        var userId = Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isAdmin = user.IsInRole("Admin");

        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (!isAdmin && combo.OwnerId != userId)
            throw new UnauthorizedAccessException("You do not have permission to delete this combo.");

        await _repo.DeleteAsync(request.ComboId, cancellationToken);
    }
}
