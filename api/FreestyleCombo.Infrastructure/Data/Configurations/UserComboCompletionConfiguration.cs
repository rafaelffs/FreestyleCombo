using FreestyleCombo.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FreestyleCombo.Infrastructure.Data.Configurations;

public class UserComboCompletionConfiguration : IEntityTypeConfiguration<UserComboCompletion>
{
    public void Configure(EntityTypeBuilder<UserComboCompletion> builder)
    {
        builder.HasKey(c => new { c.UserId, c.ComboId });
        builder.Property(c => c.CreatedAt).IsRequired();

        builder.HasOne(c => c.User)
            .WithMany(u => u.CompletedCombos)
            .HasForeignKey(c => c.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(c => c.Combo)
            .WithMany(co => co.CompletedBy)
            .HasForeignKey(c => c.ComboId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.ToTable("UserComboCompletions");
    }
}
