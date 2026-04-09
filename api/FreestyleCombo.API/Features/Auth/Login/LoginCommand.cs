using MediatR;

namespace FreestyleCombo.API.Features.Auth.Login;

public record LoginCommand(string Email, string Password) : IRequest<LoginResponse>;
