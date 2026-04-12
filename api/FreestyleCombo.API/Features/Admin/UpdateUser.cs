using FluentValidation;
using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Admin;

public record UpdateUserCommand(Guid UserId, string? UserName, string? Email) : IRequest<AdminUserDto>;

public class UpdateUserValidator : AbstractValidator<UpdateUserCommand>
{
    public UpdateUserValidator()
    {
        When(x => x.UserName != null, () =>
            RuleFor(x => x.UserName).NotEmpty().MinimumLength(3).MaximumLength(256));
        When(x => x.Email != null, () =>
            RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256));
    }
}

public class UpdateUserHandler : IRequestHandler<UpdateUserCommand, AdminUserDto>
{
    private readonly UserManager<AppUser> _userManager;

    public UpdateUserHandler(UserManager<AppUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task<AdminUserDto> Handle(UpdateUserCommand request, CancellationToken cancellationToken)
    {
        var user = await _userManager.FindByIdAsync(request.UserId.ToString())
            ?? throw new InvalidOperationException("User not found.");

        if (request.UserName != null && request.UserName != user.UserName)
        {
            var result = await _userManager.SetUserNameAsync(user, request.UserName);
            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join("; ", result.Errors.Select(e => e.Description)));
        }

        if (request.Email != null && request.Email != user.Email)
        {
            var token = await _userManager.GenerateChangeEmailTokenAsync(user, request.Email);
            var result = await _userManager.ChangeEmailAsync(user, request.Email, token);
            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join("; ", result.Errors.Select(e => e.Description)));
        }

        var roles = await _userManager.GetRolesAsync(user);
        return new AdminUserDto(user.Id, user.UserName!, user.Email!, roles.Contains("Admin"), 0);
    }
}
