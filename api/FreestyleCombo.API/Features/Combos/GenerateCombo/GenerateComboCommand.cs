using MediatR;

namespace FreestyleCombo.API.Features.Combos.GenerateCombo;

public record GenerateComboCommand(
    bool UsePreferences,
    GenerateComboOverrides? Overrides,
    string? Name = null
) : IRequest<GenerateComboResponse>;

public class GenerateComboOverrides
{
    public int? MaxDifficulty { get; set; }
    public int? ComboLength { get; set; }
    public int? StrongFootPercentage { get; set; }
    public int? NoTouchPercentage { get; set; }
    public int? MaxConsecutiveNoTouch { get; set; }
    public bool? IncludeCrossOver { get; set; }
    public bool? IncludeKnee { get; set; }
    public List<decimal>? AllowedRevolutions { get; set; }
}
