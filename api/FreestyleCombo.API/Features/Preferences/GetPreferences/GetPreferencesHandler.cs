using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Preferences.GetPreferences;

public class GetPreferencesHandler : IRequestHandler<GetPreferencesQuery, List<PreferenceDto>>
{
    private readonly IUserPreferenceRepository _repo;

    public GetPreferencesHandler(IUserPreferenceRepository repo) => _repo = repo;

    public async Task<List<PreferenceDto>> Handle(GetPreferencesQuery request, CancellationToken cancellationToken)
    {
        var prefs = await _repo.GetAllByUserIdAsync(request.UserId, cancellationToken);

        return prefs.Select(p => new PreferenceDto
        {
            Id = p.Id,
            Name = p.Name,
            MaxDifficulty = p.MaxDifficulty,
            ComboLength = p.ComboLength,
            StrongFootPercentage = p.StrongFootPercentage,
            NoTouchPercentage = p.NoTouchPercentage,
            MaxConsecutiveNoTouch = p.MaxConsecutiveNoTouch,
            IncludeCrossOver = p.IncludeCrossOver,
            IncludeKnee = p.IncludeKnee,
            AllowedRevolutions = p.AllowedRevolutions
        }).ToList();
    }
}
