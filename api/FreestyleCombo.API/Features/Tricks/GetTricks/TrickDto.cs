using FreestyleCombo.API.Features.Combos.GenerateCombo;

namespace FreestyleCombo.API.Features.Tricks.GetTricks;

public class TrickListItemDto
{
    public string Type { get; set; } = "trick";  // "trick" | "combo"

    // Populated when Type == "trick" (all existing trick fields)
    public Guid? Id { get; set; }
    public string? Name { get; set; }
    public string? Abbreviation { get; set; }
    public bool CrossOver { get; set; }
    public bool Knee { get; set; }
    public decimal Revolution { get; set; }
    public int Difficulty { get; set; }
    public bool IsTransition { get; set; }

    // Populated when Type == "combo"
    public decimal? TotalDifficulty { get; set; }
    public int? TrickCount { get; set; }
    public List<ComboTrickDto>? Tricks { get; set; }
}
