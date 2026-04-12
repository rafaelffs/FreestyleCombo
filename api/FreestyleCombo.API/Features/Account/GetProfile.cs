using System.Security.Claims;
using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Account;

public record GetProfileQuery : IRequest<ProfileDto>;

public record ProfileDto(Guid Id, string UserName, string Email, bool IsAdmin);

public class GetProfileHandler : IRequestHandler<GetProfileQuery, ProfileDto>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly IHttpContextAccessor _http;

    public GetProfileHandler(UserManager<AppUser> userManager, IHttpContextAccessor http)
    {
        _userManager = userManager;
        _http = http;
    }

    public async Task<ProfileDto> Handle(GetProfileQuery request, CancellationToken cancellationToken)
    {
        var userId = _http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var user = await _userManager.FindByIdAsync(userId)
            ?? throw new InvalidOperationException("User not found.");

        var roles = await _userManager.GetRolesAsync(user);
        return new ProfileDto(user.Id, user.UserName!, user.Email!, roles.Contains("Admin"));
    }
}
