using FreestyleCombo.AI.Services;
using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Auth.ForgotPassword;

public class ForgotPasswordHandler : IRequestHandler<ForgotPasswordCommand>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly IEmailService _emailService;

    public ForgotPasswordHandler(UserManager<AppUser> userManager, IEmailService emailService)
    {
        _userManager = userManager;
        _emailService = emailService;
    }

    public async Task Handle(ForgotPasswordCommand request, CancellationToken cancellationToken)
    {
        var user = await _userManager.FindByEmailAsync(request.Email);
        // Never reveal whether an account exists for this email.
        if (user == null) return;

        var code = Random.Shared.Next(0, 1_000_000).ToString("D6");
        user.PasswordResetCodeHash = PasswordResetCodeHasher.Hash(code);
        user.PasswordResetCodeExpiresAt = DateTime.UtcNow.AddMinutes(15);
        await _userManager.UpdateAsync(user);

        await _emailService.SendPasswordResetCodeAsync(request.Email, code, cancellationToken);
    }
}
