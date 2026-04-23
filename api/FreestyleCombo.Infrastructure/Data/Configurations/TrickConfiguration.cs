using FreestyleCombo.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FreestyleCombo.Infrastructure.Data.Configurations;

public class TrickConfiguration : IEntityTypeConfiguration<Trick>
{
    public void Configure(EntityTypeBuilder<Trick> builder)
    {
        builder.HasKey(t => t.Id);
        builder.Property(t => t.Id).ValueGeneratedOnAdd();
        builder.Property(t => t.Name).HasMaxLength(100).IsRequired();
        builder.Property(t => t.Abbreviation).HasMaxLength(20).IsRequired();
        builder.Property(t => t.Revolution).HasPrecision(3, 1);
        builder.Property(t => t.Difficulty).IsRequired();
        builder.Property(t => t.CommonLevel).IsRequired();
        builder.Property(t => t.CreatedBy).HasMaxLength(100);
        builder.Property(t => t.Notes).HasMaxLength(500);
    }
}
