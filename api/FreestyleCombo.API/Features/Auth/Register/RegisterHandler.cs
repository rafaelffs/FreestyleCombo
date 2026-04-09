using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Auth.Register;

public class RegisterHandler : IRequestHandler<RegisterCommand, RegisterResponse>
{
    private readonly UserManager<AppUser> _userManager;

    public RegisterHandler(UserManager<AppUser> userManager) => _userManager = userManager;

    public async Task<RegisterResponse> Handle(RegisterCommand request, CancellationToken cancellationToken)
    {
        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = request.Email,
            UserName = request.UserName
        };

        var result = await _userManager.CreateAsync(user, request.Password);

        if (!result.Succeeded)
        {
            var errors = string.Join("; ", result.Errors.Select(e => e.Description));
            throw new InvalidOperationException(errors);
        }

        return new RegisterResponse(user.Id, user.Email!, user.UserName!);
    }
}
