using FreestyleCombo.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FreestyleCombo.Infrastructure.Data.Configurations;

public class ComboTrickConfiguration : IEntityTypeConfiguration<ComboTrick>
{
    public void Configure(EntityTypeBuilder<ComboTrick> builder)
    {
        builder.HasKey(ct => ct.Id);
        builder.Property(ct => ct.Id).ValueGeneratedOnAdd();

        builder.HasOne(ct => ct.Combo)
            .WithMany(c => c.ComboTricks)
            .HasForeignKey(ct => ct.ComboId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(ct => ct.Trick)
            .WithMany(t => t.ComboTricks)
            .HasForeignKey(ct => ct.TrickId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
