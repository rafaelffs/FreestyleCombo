using MediatR;

namespace FreestyleCombo.API.Features.Preferences.GetPreferences;

public record GetPreferencesQuery(Guid UserId) : IRequest<List<PreferenceDto>>;

public class PreferenceDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int MaxDifficulty { get; set; }
    public int ComboLength { get; set; }
    public int StrongFootPercentage { get; set; }
    public int NoTouchPercentage { get; set; }
    public int MaxConsecutiveNoTouch { get; set; }
    public bool IncludeCrossOver { get; set; }
    public bool IncludeKnee { get; set; }
    public List<decimal> AllowedRevolutions { get; set; } = [];
}
