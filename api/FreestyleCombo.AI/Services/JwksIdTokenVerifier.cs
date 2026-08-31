using System.Collections.Concurrent;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace FreestyleCombo.AI.Services;

// Verifies Google/Apple ID tokens directly against each provider's public
// JWKS — no vendor SDK dependency server-side. Fails closed: any signature,
// issuer, audience, or lifetime problem returns null rather than throwing,
// so callers can turn "not verified" into a clean 403 instead of a 500.
public class JwksIdTokenVerifier : IIdTokenVerifier
{
    private static readonly IReadOnlyDictionary<string, (string MetadataAddress, string[] Issuers)> Providers =
        new Dictionary<string, (string, string[])>
        {
            ["google"] = ("https://accounts.google.com/.well-known/openid-configuration",
                new[] { "accounts.google.com", "https://accounts.google.com" }),
            ["apple"] = ("https://appleid.apple.com/.well-known/openid-configuration",
                new[] { "https://appleid.apple.com" }),
        };

    private static readonly ConcurrentDictionary<string, ConfigurationManager<OpenIdConnectConfiguration>> ConfigManagers = new();

    private readonly IConfiguration _config;
    private readonly ILogger<JwksIdTokenVerifier> _logger;

    public JwksIdTokenVerifier(IConfiguration config, ILogger<JwksIdTokenVerifier> logger)
    {
        _config = config;
        _logger = logger;
    }

    public async Task<ExternalIdentity?> VerifyAsync(string provider, string idToken, CancellationToken ct = default)
    {
        if (!Providers.TryGetValue(provider, out var providerInfo))
            return null;

        var audiencesRaw = _config[$"Auth:{Capitalize(provider)}:Audiences"];
        var audiences = (audiencesRaw ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (audiences.Length == 0)
        {
            _logger.LogWarning("No configured audiences for provider {Provider}; rejecting token.", provider);
            return null;
        }

        var configManager = ConfigManagers.GetOrAdd(provider, _ =>
            new ConfigurationManager<OpenIdConnectConfiguration>(
                providerInfo.MetadataAddress,
                new OpenIdConnectConfigurationRetriever()));

        try
        {
            var openIdConfig = await configManager.GetConfigurationAsync(ct);

            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                RequireSignedTokens = true,
                ValidIssuers = providerInfo.Issuers,
                ValidAudiences = audiences,
                IssuerSigningKeys = openIdConfig.SigningKeys,
            };

            var result = await new JsonWebTokenHandler().ValidateTokenAsync(idToken, validationParameters);
            if (!result.IsValid)
            {
                _logger.LogWarning(result.Exception, "Rejected {Provider} ID token: invalid.", provider);
                return null;
            }

            if (result.Claims.TryGetValue("sub", out var subObj) && subObj is string subject && !string.IsNullOrWhiteSpace(subject))
            {
                var email = result.Claims.TryGetValue("email", out var emailObj) ? emailObj as string : null;
                var name = result.Claims.TryGetValue("name", out var nameObj) ? nameObj as string : null;
                return new ExternalIdentity(subject, email, name);
            }

            _logger.LogWarning("Rejected {Provider} ID token: missing sub claim.", provider);
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to verify {Provider} ID token.", provider);
            return null;
        }
    }

    private static string Capitalize(string s) => char.ToUpperInvariant(s[0]) + s[1..];
}
