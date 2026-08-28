namespace FreestyleCombo.AI.Services;

public interface IEmailService
{
    Task SendPasswordResetCodeAsync(string toEmail, string code, CancellationToken ct = default);
}
