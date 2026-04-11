using FreestyleCombo.Core.Entities;
using FreestyleCombo.Infrastructure.Data.Configurations;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.Infrastructure.Data;

public class AppDbContext : IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Trick> Tricks => Set<Trick>();
    public DbSet<Combo> Combos => Set<Combo>();
    public DbSet<ComboTrick> ComboTricks => Set<ComboTrick>();
    public DbSet<ComboRating> ComboRatings => Set<ComboRating>();
    public DbSet<UserPreference> UserPreferences => Set<UserPreference>();
    public DbSet<TrickSubmission> TrickSubmissions => Set<TrickSubmission>();
    public DbSet<UserFavouriteCombo> UserFavouriteCombos => Set<UserFavouriteCombo>();
    public DbSet<UserComboCompletion> UserComboCompletions => Set<UserComboCompletion>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);
        builder.ApplyConfiguration(new TrickConfiguration());
        builder.ApplyConfiguration(new ComboConfiguration());
        builder.ApplyConfiguration(new ComboTrickConfiguration());
        builder.ApplyConfiguration(new ComboRatingConfiguration());
        builder.ApplyConfiguration(new UserPreferenceConfiguration());
        builder.ApplyConfiguration(new TrickSubmissionConfiguration());
        builder.ApplyConfiguration(new UserFavouriteComboConfiguration());
        builder.ApplyConfiguration(new UserComboCompletionConfiguration());
    }
}
