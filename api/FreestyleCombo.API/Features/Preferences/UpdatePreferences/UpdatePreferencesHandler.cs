using FreestyleCombo.API.Features.Preferences.GetPreferences;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Preferences.UpdatePreferences;

public class UpdatePreferencesHandler : IRequestHandler<UpdatePreferencesCommand, PreferenceDto>
{
    private readonly IUserPreferenceRepository _repo;

    public UpdatePreferencesHandler(IUserPreferenceRepository repo) => _repo = repo;

    public async Task<PreferenceDto> Handle(UpdatePreferencesCommand request, CancellationToken cancellationToken)
    {
        var pref = await _repo.GetByIdAsync(request.PreferenceId, cancellationToken)
            ?? throw new KeyNotFoundException("Preference not found.");

        if (pref.UserId != request.CallerId)
            throw new UnauthorizedAccessException("You can only edit your own preferences.");

        pref.Name = request.Name;
        pref.MaxDifficulty = request.MaxDifficulty;
        pref.ComboLength = request.ComboLength;
        pref.StrongFootPercentage = request.StrongFootPercentage;
        pref.NoTouchPercentage = request.NoTouchPercentage;
        pref.MaxConsecutiveNoTouch = request.MaxConsecutiveNoTouch;
        pref.IncludeCrossOver = request.IncludeCrossOver;
        pref.IncludeKnee = request.IncludeKnee;
        pref.AllowedRevolutions = request.AllowedRevolutions;

        await _repo.UpdateAsync(pref, cancellationToken);

        return new PreferenceDto
        {
            Id = pref.Id,
            Name = pref.Name,
            MaxDifficulty = pref.MaxDifficulty,
            ComboLength = pref.ComboLength,
            StrongFootPercentage = pref.StrongFootPercentage,
            NoTouchPercentage = pref.NoTouchPercentage,
            MaxConsecutiveNoTouch = pref.MaxConsecutiveNoTouch,
            IncludeCrossOver = pref.IncludeCrossOver,
            IncludeKnee = pref.IncludeKnee,
            AllowedRevolutions = pref.AllowedRevolutions
        };
    }
}
