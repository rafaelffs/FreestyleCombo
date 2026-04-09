using Anthropic.SDK;
using Anthropic.SDK.Constants;
using Anthropic.SDK.Messaging;
using FreestyleCombo.AI.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace FreestyleCombo.AI.Services;

public class ComboEnhancerService : IComboEnhancerService
{
    private readonly IConfiguration _config;
    private readonly ILogger<ComboEnhancerService> _logger;

    public ComboEnhancerService(IConfiguration config, ILogger<ComboEnhancerService> logger)
    {
        _config = config;
        _logger = logger;
    }

    public async Task<ComboEnhancementResponse> EnhanceAsync(ComboEnhancementRequest request, CancellationToken ct = default)
    {
        var apiKey = _config["Anthropic:ApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            _logger.LogWarning("Anthropic API key not configured; skipping AI description.");
            return new ComboEnhancementResponse { Description = string.Empty };
        }

        try
        {
            var client = new AnthropicClient(apiKey);

            var comboDisplay = string.Join(" ", request.Tricks
                .OrderBy(t => t.Position)
                .Select(t => t.NoTouch ? $"{t.Abbreviation}(nt)" : t.Abbreviation));

            var prompt = $"""
                You are a freestyle football expert. Describe the following combo in 2-3 engaging sentences,
                highlighting the flow, difficulty and any notable transitions.

                Combo: {comboDisplay}
                Total difficulty: {request.TotalDifficulty}

                Tricks:
                {string.Join("\n", request.Tricks.OrderBy(t => t.Position).Select(t =>
                    $"- {t.Name} ({t.Abbreviation}): {t.Motion} revolution(s), difficulty {t.Difficulty}" +
                    (t.CrossOver ? ", crossover" : "") +
                    (t.NoTouch ? ", no-touch into next" : "") +
                    (t.StrongFoot ? ", strong foot" : ", weak foot")
                ))}

                Respond with only the description, no preamble.
                """;

            var messageRequest = new MessageParameters
            {
                Model = AnthropicModels.Claude45Haiku,
                MaxTokens = 300,
                Messages =
                [
                    new Message(RoleType.User, prompt)
                ]
            };

            var response = await client.Messages.GetClaudeMessageAsync(messageRequest, ct);
            var text = response.Content.OfType<TextContent>().FirstOrDefault()?.Text ?? string.Empty;
            return new ComboEnhancementResponse { Description = text.Trim() };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get AI description for combo.");
            return new ComboEnhancementResponse { Description = string.Empty };
        }
    }
}
