using FreestyleCombo.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace FreestyleCombo.AI.Training;

public class ComboRatingAggregator
{
    private readonly IComboRatingRepository _ratingRepo;
    private readonly IComboRepository _comboRepo;
    private readonly ITrickRepository _trickRepo;
    private readonly ILogger<ComboRatingAggregator> _logger;

    public ComboRatingAggregator(
        IComboRatingRepository ratingRepo,
        IComboRepository comboRepo,
        ITrickRepository trickRepo,
        ILogger<ComboRatingAggregator> logger)
    {
        _ratingRepo = ratingRepo;
        _comboRepo = comboRepo;
        _trickRepo = trickRepo;
        _logger = logger;
    }

    public virtual async Task AdjustWeightsAsync(CancellationToken ct = default)
    {
        var allTricks = await _trickRepo.GetAllAsync(ct: ct);

        // For each trick, compute average rating across all combos it appears in
        var trickScores = new Dictionary<Guid, List<double>>();

        foreach (var trick in allTricks)
        {
            foreach (var comboTrick in trick.ComboTricks ?? [])
            {
                var ratings = await _ratingRepo.GetByComboAsync(comboTrick.ComboId, ct);
                if (ratings.Count == 0) continue;

                var avg = ratings.Average(r => r.Score);
                if (!trickScores.ContainsKey(trick.Id))
                    trickScores[trick.Id] = [];
                trickScores[trick.Id].Add(avg);
            }
        }

        foreach (var trick in allTricks)
        {
            if (!trickScores.TryGetValue(trick.Id, out var scores) || scores.Count < 3)
                continue;

            var avg = scores.Average();

            if (avg >= 4.0 && trick.CommonLevel < 5)
            {
                trick.CommonLevel++;
                await _trickRepo.UpdateAsync(trick, ct);
                _logger.LogInformation("Increased CommonLevel for {Trick} to {Level}", trick.Abbreviation, trick.CommonLevel);
            }
            else if (avg <= 2.0 && trick.CommonLevel > 1)
            {
                trick.CommonLevel--;
                await _trickRepo.UpdateAsync(trick, ct);
                _logger.LogInformation("Decreased CommonLevel for {Trick} to {Level}", trick.Abbreviation, trick.CommonLevel);
            }
        }
    }
}
