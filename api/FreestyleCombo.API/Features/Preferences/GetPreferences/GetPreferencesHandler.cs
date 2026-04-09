using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Preferences.GetPreferences;

public class GetPreferencesHandler : IRequestHandler<GetPreferencesQuery, PreferenceDto>
{
    private readonly IUserPreferenceRepository _repo;

    public GetPreferencesHandler(IUserPreferenceRepository repo) => _repo = repo;

    public async Task<PreferenceDto> Handle(GetPreferencesQuery request, CancellationToken cancellationToken)
    {
        var pref = await _repo.GetByUserIdAsync(request.UserId, cancellationToken);

        if (pref == null)
        {
            // Return defaults
            pref = new UserPreference
            {
                Id = Guid.Empty,
                UserId = request.UserId
            };
        }

        return new PreferenceDto
        {
            Id = pref.Id,
            MaxDifficulty = pref.MaxDifficulty,
            ComboLength = pref.ComboLength,
            StrongFootPercentage = pref.StrongFootPercentage,
            NoTouchPercentage = pref.NoTouchPercentage,
            MaxConsecutiveNoTouch = pref.MaxConsecutiveNoTouch,
            IncludeCrossOver = pref.IncludeCrossOver,
            IncludeKnee = pref.IncludeKnee,
            AllowedMotions = pref.AllowedMotions
        };
    }
}
