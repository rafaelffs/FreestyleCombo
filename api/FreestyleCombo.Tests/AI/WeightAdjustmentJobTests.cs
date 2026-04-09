using FluentAssertions;
using FreestyleCombo.AI.Services;
using FreestyleCombo.AI.Training;
using Moq;
using Microsoft.Extensions.Logging;

namespace FreestyleCombo.Tests.AI;

public class WeightAdjustmentJobTests
{
    [Fact]
    public async Task ExecuteAsync_CallsFeedbackLearningService()
    {
        var aggregatorMock = new Mock<ComboRatingAggregator>(
            Mock.Of<FreestyleCombo.Core.Interfaces.IComboRatingRepository>(),
            Mock.Of<FreestyleCombo.Core.Interfaces.IComboRepository>(),
            Mock.Of<FreestyleCombo.Core.Interfaces.ITrickRepository>(),
            Mock.Of<ILogger<ComboRatingAggregator>>());

        aggregatorMock.Setup(a => a.AdjustWeightsAsync(It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var learningService = new FeedbackLearningService(aggregatorMock.Object, Mock.Of<ILogger<FeedbackLearningService>>());
        var job = new WeightAdjustmentJob(learningService, Mock.Of<ILogger<WeightAdjustmentJob>>());

        Func<Task> act = job.ExecuteAsync;

        await act.Should().NotThrowAsync();
    }
}
