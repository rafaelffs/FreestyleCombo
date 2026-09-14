using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Account;

public record GetPublicProfileQuery(Guid UserId) : IRequest<PublicProfileDto>;

// No Email — this endpoint has no [Authorize] (anyone can look up any user's
// profile by id, e.g. via a combo's "by [username]" link), so an email field
// here would be a public data leak, not just a UI display choice.
public record PublicProfileDto(Guid Id, string UserName);

public class GetPublicProfileHandler : IRequestHandler<GetPublicProfileQuery, PublicProfileDto>
{
    private readonly UserManager<AppUser> _userManager;

    public GetPublicProfileHandler(UserManager<AppUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task<PublicProfileDto> Handle(GetPublicProfileQuery request, CancellationToken cancellationToken)
    {
        var user = await _userManager.FindByIdAsync(request.UserId.ToString())
            ?? throw new InvalidOperationException("User not found.");

        return new PublicProfileDto(user.Id, user.UserName!);
    }
}
