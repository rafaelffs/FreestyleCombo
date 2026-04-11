using FreestyleCombo.API.Features.Preferences.GetPreferences;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Preferences.CreatePreference;

public class CreatePreferenceHandler : IRequestHandler<CreatePreferenceCommand, PreferenceDto>
{
    private readonly IUserPreferenceRepository _repo;

    public CreatePreferenceHandler(IUserPreferenceRepository repo) => _repo = repo;

    public async Task<PreferenceDto> Handle(CreatePreferenceCommand request, CancellationToken cancellationToken)
    {
        var pref = new UserPreference
        {
            Id = Guid.NewGuid(),
            UserId = request.UserId,
            Name = request.Name,
            MaxDifficulty = request.MaxDifficulty,
            ComboLength = request.ComboLength,
            StrongFootPercentage = request.StrongFootPercentage,
            NoTouchPercentage = request.NoTouchPercentage,
            MaxConsecutiveNoTouch = request.MaxConsecutiveNoTouch,
            IncludeCrossOver = request.IncludeCrossOver,
            IncludeKnee = request.IncludeKnee,
            AllowedRevolutions = request.AllowedRevolutions
        };

        await _repo.AddAsync(pref, cancellationToken);

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
