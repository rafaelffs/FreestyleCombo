using FreestyleCombo.Core.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Account;

public record GetPublicProfileQuery(Guid UserId) : IRequest<PublicProfileDto>;

public record PublicProfileDto(Guid Id, string UserName, string Email);

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

        return new PublicProfileDto(user.Id, user.UserName!, user.Email!);
    }
}
