using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Auth.ResetPassword;

public class ResetPasswordHandler : IRequestHandler<ResetPasswordCommand>
{
    private readonly UserManager<AppUser> _userManager;

    public ResetPasswordHandler(UserManager<AppUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task Handle(ResetPasswordCommand request, CancellationToken cancellationToken)
    {
        var user = await _userManager.FindByEmailAsync(request.Email);

        if (user?.PasswordResetCodeHash == null
            || user.PasswordResetCodeExpiresAt == null
            || user.PasswordResetCodeExpiresAt < DateTime.UtcNow
            || user.PasswordResetCodeHash != PasswordResetCodeHasher.Hash(request.Code))
        {
            throw new InvalidOperationException("Invalid or expired code.");
        }

        var removeResult = await _userManager.RemovePasswordAsync(user);
        if (!removeResult.Succeeded)
            throw new InvalidOperationException(string.Join("; ", removeResult.Errors.Select(e => e.Description)));

        var addResult = await _userManager.AddPasswordAsync(user, request.NewPassword);
        if (!addResult.Succeeded)
            throw new InvalidOperationException(string.Join("; ", addResult.Errors.Select(e => e.Description)));

        user.PasswordResetCodeHash = null;
        user.PasswordResetCodeExpiresAt = null;
        await _userManager.UpdateAsync(user);
    }
}
