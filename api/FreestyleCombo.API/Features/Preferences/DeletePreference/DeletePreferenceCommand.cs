using MediatR;

namespace FreestyleCombo.API.Features.Preferences.DeletePreference;

public record DeletePreferenceCommand(Guid PreferenceId, Guid CallerId) : IRequest;
