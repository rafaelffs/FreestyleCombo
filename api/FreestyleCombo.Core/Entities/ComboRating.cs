namespace FreestyleCombo.Core.Entities;

public class ComboRating
{
    public Guid Id { get; set; }
    public Guid ComboId { get; set; }
    public Guid RatedByUserId { get; set; }
    public int Score { get; set; }
    public DateTime CreatedAt { get; set; }

    public Combo Combo { get; set; } = null!;
    public AppUser RatedByUser { get; set; } = null!;
}
