using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace FreestyleCombo.AI.Services;

public class ResendEmailService : IEmailService
{
    private readonly HttpClient _http;
    private readonly IConfiguration _config;
    private readonly ILogger<ResendEmailService> _logger;

    public ResendEmailService(HttpClient http, IConfiguration config, ILogger<ResendEmailService> logger)
    {
        _http = http;
        _config = config;
        _logger = logger;
    }

    public async Task SendPasswordResetCodeAsync(string toEmail, string code, CancellationToken ct = default)
    {
        var apiKey = _config["Resend:ApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            _logger.LogWarning("Resend API key not configured; skipping password reset email.");
            return;
        }

        var fromAddress = _config["Resend:FromAddress"] ?? "FreestyleCombo <onboarding@resend.dev>";

        try
        {
            var request = new HttpRequestMessage(HttpMethod.Post, "https://api.resend.com/emails")
            {
                Content = JsonContent.Create(new
                {
                    from = fromAddress,
                    to = new[] { toEmail },
                    subject = "Reset your FreestyleCombo password",
                    html = $"""
                        <p>Use this code to reset your FreestyleCombo password:</p>
                        <h2 style="letter-spacing: 4px;">{code}</h2>
                        <p>This code expires in 15 minutes. If you didn't request this, you can safely ignore this email.</p>
                        """
                })
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);

            var response = await _http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(ct);
                _logger.LogError("Failed to send password reset email: {Status} {Body}", response.StatusCode, body);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send password reset email.");
        }
    }
}
