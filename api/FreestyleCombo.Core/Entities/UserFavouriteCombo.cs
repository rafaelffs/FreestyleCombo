namespace FreestyleCombo.Core.Entities;

public class UserFavouriteCombo
{
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    public Guid ComboId { get; set; }
    public Combo Combo { get; set; } = null!;
    public DateTime CreatedAt { get; set; }
}
