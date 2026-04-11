using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Preferences.DeletePreference;

public class DeletePreferenceHandler : IRequestHandler<DeletePreferenceCommand>
{
    private readonly IUserPreferenceRepository _repo;

    public DeletePreferenceHandler(IUserPreferenceRepository repo) => _repo = repo;

    public async Task Handle(DeletePreferenceCommand request, CancellationToken cancellationToken)
    {
        var pref = await _repo.GetByIdAsync(request.PreferenceId, cancellationToken)
            ?? throw new KeyNotFoundException("Preference not found.");

        if (pref.UserId != request.CallerId)
            throw new UnauthorizedAccessException("You can only delete your own preferences.");

        await _repo.DeleteAsync(pref, cancellationToken);
    }
}
