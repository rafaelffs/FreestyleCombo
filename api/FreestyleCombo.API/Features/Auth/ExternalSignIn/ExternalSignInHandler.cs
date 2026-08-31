using FreestyleCombo.AI.Services;
using FreestyleCombo.API.Features.Auth.Login;
using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.API.Features.Auth.ExternalSignIn;

public class ExternalSignInHandler : IRequestHandler<ExternalSignInCommand, LoginResponse>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly IIdTokenVerifier _verifier;
    private readonly ITokenService _tokenService;

    public ExternalSignInHandler(UserManager<AppUser> userManager, IIdTokenVerifier verifier, ITokenService tokenService)
    {
        _userManager = userManager;
        _verifier = verifier;
        _tokenService = tokenService;
    }

    public async Task<LoginResponse> Handle(ExternalSignInCommand request, CancellationToken cancellationToken)
    {
        var identity = await _verifier.VerifyAsync(request.Provider, request.IdToken, cancellationToken)
            ?? throw new UnauthorizedAccessException("Invalid or expired sign-in token.");

        var user = await _userManager.Users.FirstOrDefaultAsync(
            u => u.AuthProvider == request.Provider && u.ExternalSubject == identity.Subject,
            cancellationToken);

        if (user == null && !string.IsNullOrWhiteSpace(identity.Email))
        {
            user = await _userManager.FindByEmailAsync(identity.Email);
            if (user != null)
            {
                user.AuthProvider = request.Provider;
                user.ExternalSubject = identity.Subject;
                await _userManager.UpdateAsync(user);
            }
        }

        if (user == null)
        {
            if (string.IsNullOrWhiteSpace(identity.Email))
                throw new UnauthorizedAccessException("Unable to sign in with this account.");

            var userName = await GenerateUniqueUserNameAsync(identity.Email);
            user = new AppUser
            {
                Id = Guid.NewGuid(),
                Email = identity.Email,
                UserName = userName,
                EmailConfirmed = true,
                AuthProvider = request.Provider,
                ExternalSubject = identity.Subject,
            };

            var result = await _userManager.CreateAsync(user);
            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join("; ", result.Errors.Select(e => e.Description)));
        }

        var roles = await _userManager.GetRolesAsync(user);
        var (token, expiresAt) = _tokenService.CreateToken(user, roles);

        return new LoginResponse(token, expiresAt, user.Id);
    }

    private async Task<string> GenerateUniqueUserNameAsync(string email)
    {
        var local = email.Split('@')[0];
        var baseName = new string(local.Where(char.IsLetterOrDigit).ToArray()).ToLowerInvariant();
        if (baseName.Length < 3) baseName = "user";
        if (baseName.Length > 50) baseName = baseName[..50];

        var candidate = baseName;
        var suffix = 2;
        while (await _userManager.FindByNameAsync(candidate) != null)
        {
            candidate = $"{baseName}{suffix}";
            suffix++;
        }

        return candidate;
    }
}
