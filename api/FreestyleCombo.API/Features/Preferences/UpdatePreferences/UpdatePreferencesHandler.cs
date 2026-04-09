using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Preferences.UpdatePreferences;

public class UpdatePreferencesHandler : IRequestHandler<UpdatePreferencesCommand>
{
    private readonly IUserPreferenceRepository _repo;

    public UpdatePreferencesHandler(IUserPreferenceRepository repo) => _repo = repo;

    public async Task Handle(UpdatePreferencesCommand request, CancellationToken cancellationToken)
    {
        var pref = await _repo.GetByUserIdAsync(request.UserId, cancellationToken);
        bool isNew = pref == null;

        pref ??= new UserPreference { Id = Guid.NewGuid(), UserId = request.UserId };

        if (request.MaxDifficulty.HasValue) pref.MaxDifficulty = request.MaxDifficulty.Value;
        if (request.ComboLength.HasValue) pref.ComboLength = request.ComboLength.Value;
        if (request.StrongFootPercentage.HasValue) pref.StrongFootPercentage = request.StrongFootPercentage.Value;
        if (request.NoTouchPercentage.HasValue) pref.NoTouchPercentage = request.NoTouchPercentage.Value;
        if (request.MaxConsecutiveNoTouch.HasValue) pref.MaxConsecutiveNoTouch = request.MaxConsecutiveNoTouch.Value;
        if (request.IncludeCrossOver.HasValue) pref.IncludeCrossOver = request.IncludeCrossOver.Value;
        if (request.IncludeKnee.HasValue) pref.IncludeKnee = request.IncludeKnee.Value;
        if (request.AllowedMotions != null) pref.AllowedMotions = request.AllowedMotions;

        if (isNew)
            await _repo.AddAsync(pref, cancellationToken);
        else
            await _repo.UpdateAsync(pref, cancellationToken);
    }
}
