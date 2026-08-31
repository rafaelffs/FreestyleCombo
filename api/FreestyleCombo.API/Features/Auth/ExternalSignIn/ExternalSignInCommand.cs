using FreestyleCombo.API.Features.Auth.Login;
using MediatR;

namespace FreestyleCombo.API.Features.Auth.ExternalSignIn;

public record ExternalSignInCommand(string Provider, string IdToken) : IRequest<LoginResponse>;
