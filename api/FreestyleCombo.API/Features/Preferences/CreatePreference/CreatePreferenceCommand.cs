using MediatR;
using FreestyleCombo.API.Features.Preferences.GetPreferences;

namespace FreestyleCombo.API.Features.Preferences.CreatePreference;

public record CreatePreferenceCommand(
    Guid UserId,
    string Name,
    int MaxDifficulty,
    int ComboLength,
    int StrongFootPercentage,
    int NoTouchPercentage,
    int MaxConsecutiveNoTouch,
    bool IncludeCrossOver,
    bool IncludeKnee,
    List<decimal> AllowedRevolutions
) : IRequest<PreferenceDto>;
