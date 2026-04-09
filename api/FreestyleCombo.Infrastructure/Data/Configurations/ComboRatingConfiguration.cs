using FreestyleCombo.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FreestyleCombo.Infrastructure.Data.Configurations;

public class ComboRatingConfiguration : IEntityTypeConfiguration<ComboRating>
{
    public void Configure(EntityTypeBuilder<ComboRating> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Id).ValueGeneratedOnAdd();
        builder.Property(r => r.Score).IsRequired();
        builder.Property(r => r.CreatedAt).IsRequired();

        builder.HasIndex(r => new { r.ComboId, r.RatedByUserId }).IsUnique();

        builder.HasOne(r => r.Combo)
            .WithMany(c => c.Ratings)
            .HasForeignKey(r => r.ComboId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(r => r.RatedByUser)
            .WithMany(u => u.Ratings)
            .HasForeignKey(r => r.RatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
