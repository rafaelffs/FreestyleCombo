using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Admin;

public record UpdateUserRoleCommand(Guid UserId, bool IsAdmin) : IRequest;

public class UpdateUserRoleHandler : IRequestHandler<UpdateUserRoleCommand>
{
    private readonly UserManager<AppUser> _userManager;

    public UpdateUserRoleHandler(UserManager<AppUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task Handle(UpdateUserRoleCommand request, CancellationToken cancellationToken)
    {
        var user = await _userManager.FindByIdAsync(request.UserId.ToString())
            ?? throw new InvalidOperationException("User not found.");

        var isCurrentlyAdmin = await _userManager.IsInRoleAsync(user, "Admin");

        if (request.IsAdmin && !isCurrentlyAdmin)
        {
            var result = await _userManager.AddToRoleAsync(user, "Admin");
            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join("; ", result.Errors.Select(e => e.Description)));
        }
        else if (!request.IsAdmin && isCurrentlyAdmin)
        {
            var result = await _userManager.RemoveFromRoleAsync(user, "Admin");
            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join("; ", result.Errors.Select(e => e.Description)));
        }
    }
}
