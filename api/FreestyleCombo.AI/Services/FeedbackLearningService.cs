using FreestyleCombo.AI.Training;
using Microsoft.Extensions.Logging;

namespace FreestyleCombo.AI.Services;

public class FeedbackLearningService
{
    private readonly ComboRatingAggregator _aggregator;
    private readonly ILogger<FeedbackLearningService> _logger;

    public FeedbackLearningService(ComboRatingAggregator aggregator, ILogger<FeedbackLearningService> logger)
    {
        _aggregator = aggregator;
        _logger = logger;
    }

    public async Task RunAsync(CancellationToken ct = default)
    {
        _logger.LogInformation("FeedbackLearningService: starting weight adjustment run.");
        await _aggregator.AdjustWeightsAsync(ct);
        _logger.LogInformation("FeedbackLearningService: weight adjustment complete.");
    }
}
