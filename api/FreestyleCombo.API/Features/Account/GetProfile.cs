using System.Security.Claims;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Account;

public record GetProfileQuery : IRequest<ProfileDto>;

public record ProfileDto(Guid Id, string UserName, string Email, bool IsAdmin, int LandedCount);

public class GetProfileHandler : IRequestHandler<GetProfileQuery, ProfileDto>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly IHttpContextAccessor _http;
    private readonly IUserComboCompletionRepository _completions;

    public GetProfileHandler(UserManager<AppUser> userManager, IHttpContextAccessor http, IUserComboCompletionRepository completions)
    {
        _userManager = userManager;
        _http = http;
        _completions = completions;
    }

    public async Task<ProfileDto> Handle(GetProfileQuery request, CancellationToken cancellationToken)
    {
        var userId = _http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var user = await _userManager.FindByIdAsync(userId)
            ?? throw new InvalidOperationException("User not found.");

        var roles = await _userManager.GetRolesAsync(user);
        // Every combo this user has personally landed, regardless of who
        // owns it or its current visibility — GetCompletedComboIdsAsync
        // already queries UserComboCompletions by UserId with no combo-side
        // filter, unlike GetMyCombos() which only covers owned combos.
        var landedIds = await _completions.GetCompletedComboIdsAsync(user.Id, cancellationToken);
        return new ProfileDto(user.Id, user.UserName!, user.Email!, roles.Contains("Admin"), landedIds.Count);
    }
}
