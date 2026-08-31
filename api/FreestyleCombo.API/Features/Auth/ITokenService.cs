using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.API.Features.Auth;

public interface ITokenService
{
    (string Token, DateTime ExpiresAt) CreateToken(AppUser user, IList<string> roles);
}
