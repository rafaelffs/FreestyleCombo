using MediatR;

namespace FreestyleCombo.API.Features.Auth.Register;

public record RegisterCommand(string Email, string UserName, string Password) : IRequest<RegisterResponse>;
