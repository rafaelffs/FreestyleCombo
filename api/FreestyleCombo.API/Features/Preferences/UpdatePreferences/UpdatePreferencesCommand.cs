using MediatR;

namespace FreestyleCombo.API.Features.Preferences.UpdatePreferences;

public record UpdatePreferencesCommand(
    Guid UserId,
    int? MaxDifficulty,
    int? ComboLength,
    int? StrongFootPercentage,
    int? NoTouchPercentage,
    int? MaxConsecutiveNoTouch,
    bool? IncludeCrossOver,
    bool? IncludeKnee,
    List<decimal>? AllowedRevolutions
) : IRequest;
