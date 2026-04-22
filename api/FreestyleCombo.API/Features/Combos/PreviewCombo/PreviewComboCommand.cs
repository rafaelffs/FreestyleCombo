using FreestyleCombo.API.Features.Combos.GenerateCombo;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.PreviewCombo;

public record PreviewComboCommand(
    Guid? PreferenceId,
    GenerateComboOverrides? Overrides
) : IRequest<PreviewComboResponse>;

public class PreviewComboResponse
{
    public List<PreviewTrickItem> Tricks { get; set; } = [];
    public List<string> Warnings { get; set; } = [];
}

public class PreviewTrickItem
{
    public Guid TrickId { get; set; }
    public string TrickName { get; set; } = string.Empty;
    public string Abbreviation { get; set; } = string.Empty;
    public int Position { get; set; }
    public bool StrongFoot { get; set; }
    public bool NoTouch { get; set; }
    public int Difficulty { get; set; }
    public bool CrossOver { get; set; }
    public decimal Revolution { get; set; }
    public bool IsTransition { get; set; }
}
