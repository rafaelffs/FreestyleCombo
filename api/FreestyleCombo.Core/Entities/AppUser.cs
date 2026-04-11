using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.Core.Entities;

public class AppUser : IdentityUser<Guid>
{
    public ICollection<Combo> Combos { get; set; } = [];
    public ICollection<ComboRating> Ratings { get; set; } = [];
    public ICollection<UserPreference> Preferences { get; set; } = [];
    public ICollection<TrickSubmission> TrickSubmissions { get; set; } = [];
    public ICollection<UserFavouriteCombo> FavouriteCombos { get; set; } = [];
    public ICollection<UserComboCompletion> CompletedCombos { get; set; } = [];
}
