using System.Security.Claims;
using FluentValidation;
using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Account;

public record UpdateProfileCommand(string? UserName, string? Email) : IRequest<ProfileDto>;

public class UpdateProfileValidator : AbstractValidator<UpdateProfileCommand>
{
    public UpdateProfileValidator()
    {
        When(x => x.UserName != null, () =>
            RuleFor(x => x.UserName).NotEmpty().MinimumLength(3).MaximumLength(256));
        When(x => x.Email != null, () =>
            RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256));
    }
}

public class UpdateProfileHandler : IRequestHandler<UpdateProfileCommand, ProfileDto>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly IHttpContextAccessor _http;

    public UpdateProfileHandler(UserManager<AppUser> userManager, IHttpContextAccessor http)
    {
        _userManager = userManager;
        _http = http;
    }

    public async Task<ProfileDto> Handle(UpdateProfileCommand request, CancellationToken cancellationToken)
    {
        var userId = _http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var user = await _userManager.FindByIdAsync(userId)
            ?? throw new InvalidOperationException("User not found.");

        if (request.UserName != null && request.UserName != user.UserName)
        {
            var setResult = await _userManager.SetUserNameAsync(user, request.UserName);
            if (!setResult.Succeeded)
                throw new InvalidOperationException(string.Join("; ", setResult.Errors.Select(e => e.Description)));
        }

        if (request.Email != null && request.Email != user.Email)
        {
            var token = await _userManager.GenerateChangeEmailTokenAsync(user, request.Email);
            var setResult = await _userManager.ChangeEmailAsync(user, request.Email, token);
            if (!setResult.Succeeded)
                throw new InvalidOperationException(string.Join("; ", setResult.Errors.Select(e => e.Description)));
        }

        var roles = await _userManager.GetRolesAsync(user);
        return new ProfileDto(user.Id, user.UserName!, user.Email!, roles.Contains("Admin"));
    }
}
