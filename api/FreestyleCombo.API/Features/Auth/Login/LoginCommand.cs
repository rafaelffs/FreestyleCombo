using MediatR;

namespace FreestyleCombo.API.Features.Auth.Login;

public record LoginCommand(string Credential, string Password) : IRequest<LoginResponse>;
