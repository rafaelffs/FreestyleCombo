using FreestyleCombo.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FreestyleCombo.Infrastructure.Data.Configurations;

public class TrickSubmissionConfiguration : IEntityTypeConfiguration<TrickSubmission>
{
    public void Configure(EntityTypeBuilder<TrickSubmission> builder)
    {
        builder.HasKey(s => s.Id);
        builder.Property(s => s.Id).ValueGeneratedOnAdd();
        builder.Property(s => s.Name).IsRequired().HasMaxLength(100);
        builder.Property(s => s.Abbreviation).IsRequired().HasMaxLength(20);
        builder.Property(s => s.Revolution).HasColumnType("decimal(5,2)");
        builder.Property(s => s.Status).HasConversion<int>();
        builder.Property(s => s.SubmittedAt).IsRequired();

        builder.HasOne(s => s.SubmittedBy)
            .WithMany(u => u.TrickSubmissions)
            .HasForeignKey(s => s.SubmittedById)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Property(s => s.ReviewedById).IsRequired(false);
    }
}
