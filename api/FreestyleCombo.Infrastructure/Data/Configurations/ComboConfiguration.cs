using FreestyleCombo.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FreestyleCombo.Infrastructure.Data.Configurations;

public class ComboConfiguration : IEntityTypeConfiguration<Combo>
{
    public void Configure(EntityTypeBuilder<Combo> builder)
    {
        builder.HasKey(c => c.Id);
        builder.Property(c => c.Id).ValueGeneratedOnAdd();
        builder.Property(c => c.CreatedAt).IsRequired();
        builder.Property(c => c.AiDescription).HasMaxLength(2000);
        builder.Property(c => c.Visibility).HasDefaultValue(ComboVisibility.Private);
        builder.Ignore(c => c.IsPublic);

        builder.HasOne(c => c.Owner)
            .WithMany(u => u.Combos)
            .HasForeignKey(c => c.OwnerId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
