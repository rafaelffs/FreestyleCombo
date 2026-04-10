using FreestyleCombo.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FreestyleCombo.Infrastructure.Data.Configurations;

public class UserFavouriteComboConfiguration : IEntityTypeConfiguration<UserFavouriteCombo>
{
    public void Configure(EntityTypeBuilder<UserFavouriteCombo> builder)
    {
        builder.HasKey(f => new { f.UserId, f.ComboId });
        builder.Property(f => f.CreatedAt).IsRequired();

        builder.HasOne(f => f.User)
            .WithMany(u => u.FavouriteCombos)
            .HasForeignKey(f => f.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(f => f.Combo)
            .WithMany(c => c.FavouritedBy)
            .HasForeignKey(f => f.ComboId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
