using FreestyleCombo.AI.Models;

namespace FreestyleCombo.AI.Services;

public interface IComboEnhancerService
{
    Task<ComboEnhancementResponse> EnhanceAsync(ComboEnhancementRequest request, CancellationToken ct = default);
}
