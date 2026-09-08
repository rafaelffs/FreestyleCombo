using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.Core.Entities;

public class AppUser : IdentityUser<Guid>
{
    // Set explicitly (UtcNow) at creation in RegisterHandler/ExternalSignInHandler
    // — the only two places an AppUser is created. Existing rows predating this
    // column were backfilled to the migration-apply time (their real registration
    // date isn't recoverable), so treat any pre-migration CreatedAt as approximate.
    public DateTime CreatedAt { get; set; }

    public ICollection<Combo> Combos { get; set; } = [];
    public ICollection<ComboRating> Ratings { get; set; } = [];
    public ICollection<UserPreference> Preferences { get; set; } = [];
    public ICollection<TrickSubmission> TrickSubmissions { get; set; } = [];
    public ICollection<UserFavouriteCombo> FavouriteCombos { get; set; } = [];
    public ICollection<UserComboCompletion> CompletedCombos { get; set; } = [];
    public ICollection<UserPersonalReusableCombo> PersonalReusableCombos { get; set; } = [];

    // "Forgot password" flow — a short-lived, hashed numeric code emailed to
    // the user, checked in ResetPasswordHandler. Null when no reset is
    // pending, or after a successful reset / on expiry.
    public string? PasswordResetCodeHash { get; set; }
    public DateTime? PasswordResetCodeExpiresAt { get; set; }

    // External (OAuth) sign-in — null for password-only accounts. AuthProvider
    // tracks the most recently linked provider ("google" | "apple");
    // ExternalSubject is that provider's `sub` claim. See
    // ExternalSignInHandler for the sign-in/link logic that reads and
    // backfills these onto an existing password account.
    public string? AuthProvider { get; set; }
    public string? ExternalSubject { get; set; }
}
