namespace FreestyleCombo.API.Features.Auth.Login;

public record LoginResponse(string Token, DateTime ExpiresAt, Guid UserId);
