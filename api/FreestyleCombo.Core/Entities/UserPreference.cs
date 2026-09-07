namespace FreestyleCombo.Core.Entities;

public class UserPreference
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int? MaxDifficulty { get; set; }
    public int? ComboLength { get; set; }
    public int StrongFootPercentage { get; set; } = 60;
    public int? NoTouchPercentage { get; set; }
    public int? MaxConsecutiveNoTouch { get; set; }
    public bool IncludeCrossOver { get; set; } = true;
    public bool IncludeKnee { get; set; } = false;
    public List<decimal> AllowedRevolutions { get; set; } = [];

    // Caps how many tricks with 3+ revolutions (the hardest, rarest moves)
    // can appear in one generated combo. Null means no cap.
    public int? MaxHighRevolutionTricks { get; set; }

    // Restricts generation to only these tricks. Empty means no restriction
    // (the full trick pool, subject to the other filters, is eligible).
    public List<Guid> AllowedTrickIds { get; set; } = [];

    public AppUser User { get; set; } = null!;
}
