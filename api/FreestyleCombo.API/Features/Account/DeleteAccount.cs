using System.Security.Claims;
using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Account;

public record DeleteAccountCommand : IRequest;

public class DeleteAccountHandler : IRequestHandler<DeleteAccountCommand>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly IHttpContextAccessor _http;

    public DeleteAccountHandler(UserManager<AppUser> userManager, IHttpContextAccessor http)
    {
        _userManager = userManager;
        _http = http;
    }

    public async Task Handle(DeleteAccountCommand request, CancellationToken cancellationToken)
    {
        var userId = _http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var user = await _userManager.FindByIdAsync(userId)
            ?? throw new InvalidOperationException("User not found.");

        var result = await _userManager.DeleteAsync(user);
        if (!result.Succeeded)
            throw new InvalidOperationException(string.Join("; ", result.Errors.Select(e => e.Description)));
    }
}
