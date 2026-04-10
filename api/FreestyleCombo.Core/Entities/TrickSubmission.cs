namespace FreestyleCombo.Core.Entities;

public enum SubmissionStatus { Pending, Approved, Rejected }

public class TrickSubmission
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Abbreviation { get; set; } = string.Empty;
    public bool CrossOver { get; set; }
    public bool Knee { get; set; }
    public decimal Motion { get; set; }
    public int Difficulty { get; set; }
    public int CommonLevel { get; set; }
    public SubmissionStatus Status { get; set; } = SubmissionStatus.Pending;
    public DateTime SubmittedAt { get; set; } = DateTime.UtcNow;
    public Guid SubmittedById { get; set; }
    public AppUser SubmittedBy { get; set; } = null!;
    public DateTime? ReviewedAt { get; set; }
    public Guid? ReviewedById { get; set; }
}
