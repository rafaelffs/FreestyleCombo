namespace FreestyleCombo.Core.Entities;

public class UserPreference
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int MaxDifficulty { get; set; } = 10;
    public int ComboLength { get; set; } = 6;
    public int StrongFootPercentage { get; set; } = 60;
    public int NoTouchPercentage { get; set; } = 30;
    public int MaxConsecutiveNoTouch { get; set; } = 2;
    public bool IncludeCrossOver { get; set; } = true;
    public bool IncludeKnee { get; set; } = true;
    public List<decimal> AllowedRevolutions { get; set; } = [];

    // Caps how many tricks with 3+ revolutions (the hardest, rarest moves)
    // can appear in one generated combo. Null means no cap.
    public int? MaxHighRevolutionTricks { get; set; }

    public AppUser User { get; set; } = null!;
}
