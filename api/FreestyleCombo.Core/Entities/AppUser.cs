using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.Core.Entities;

public class AppUser : IdentityUser<Guid>
{
    public ICollection<Combo> Combos { get; set; } = [];
    public ICollection<ComboRating> Ratings { get; set; } = [];
    public UserPreference? Preference { get; set; }
    public ICollection<TrickSubmission> TrickSubmissions { get; set; } = [];
}
