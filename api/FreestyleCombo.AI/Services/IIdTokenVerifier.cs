namespace FreestyleCombo.AI.Services;

public interface IIdTokenVerifier
{
    Task<ExternalIdentity?> VerifyAsync(string provider, string idToken, CancellationToken ct = default);
}
