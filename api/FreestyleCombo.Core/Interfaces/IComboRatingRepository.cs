using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Core.Interfaces;

public interface IComboRatingRepository
{
    Task<ComboRating?> GetByComboAndUserAsync(Guid comboId, Guid userId, CancellationToken ct = default);
    Task<(double Average, int Total, Dictionary<int, int> Distribution)> GetStatsAsync(Guid comboId, CancellationToken ct = default);
    Task AddAsync(ComboRating rating, CancellationToken ct = default);
    Task<List<ComboRating>> GetByComboAsync(Guid comboId, CancellationToken ct = default);
}
