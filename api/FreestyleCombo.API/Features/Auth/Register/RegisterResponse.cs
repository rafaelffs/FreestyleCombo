namespace FreestyleCombo.API.Features.Auth.Register;

public record RegisterResponse(Guid UserId, string Email, string UserName);
