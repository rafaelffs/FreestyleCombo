using MediatR;
using FreestyleCombo.API.Features.Preferences.GetPreferences;

namespace FreestyleCombo.API.Features.Preferences.UpdatePreferences;

public record UpdatePreferencesCommand(
    Guid PreferenceId,
    Guid CallerId,
    string Name,
    int MaxDifficulty,
    int ComboLength,
    int StrongFootPercentage,
    int NoTouchPercentage,
    int MaxConsecutiveNoTouch,
    bool IncludeCrossOver,
    bool IncludeKnee,
    List<decimal> AllowedRevolutions,
    int? MaxHighRevolutionTricks
) : IRequest<PreferenceDto>;
