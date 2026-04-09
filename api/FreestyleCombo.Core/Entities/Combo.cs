namespace FreestyleCombo.Core.Entities;

public class Combo
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public int TotalDifficulty { get; set; }
    public int TrickCount { get; set; }
    public bool IsPublic { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? AiDescription { get; set; }

    public AppUser Owner { get; set; } = null!;
    public ICollection<ComboTrick> ComboTricks { get; set; } = [];
    public ICollection<ComboRating> Ratings { get; set; } = [];
}
