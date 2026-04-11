namespace FreestyleCombo.Core.Entities;

public enum ComboVisibility { Private = 0, PendingReview = 1, Public = 2 }

public class Combo
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public string? Name { get; set; }
    public double AverageDifficulty { get; set; }
    public int TrickCount { get; set; }
    public ComboVisibility Visibility { get; set; } = ComboVisibility.Private;
    public bool IsPublic => Visibility == ComboVisibility.Public;
    public DateTime CreatedAt { get; set; }
    public string? AiDescription { get; set; }

    public AppUser Owner { get; set; } = null!;
    public ICollection<ComboTrick> ComboTricks { get; set; } = [];
    public ICollection<ComboRating> Ratings { get; set; } = [];
    public ICollection<UserFavouriteCombo> FavouritedBy { get; set; } = [];
    public ICollection<UserComboCompletion> CompletedBy { get; set; } = [];
}
