using FreestyleCombo.AI.Services;
using Microsoft.Extensions.Logging;

namespace FreestyleCombo.AI.Training;

public class WeightAdjustmentJob
{
    private readonly FeedbackLearningService _learningService;
    private readonly ILogger<WeightAdjustmentJob> _logger;

    public WeightAdjustmentJob(FeedbackLearningService learningService, ILogger<WeightAdjustmentJob> logger)
    {
        _learningService = learningService;
        _logger = logger;
    }

    public async Task ExecuteAsync()
    {
        _logger.LogInformation("WeightAdjustmentJob started at {Time}", DateTimeOffset.UtcNow);
        await _learningService.RunAsync();
        _logger.LogInformation("WeightAdjustmentJob finished at {Time}", DateTimeOffset.UtcNow);
    }
}
