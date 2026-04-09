namespace FreestyleCombo.API.Features.Combos.GetPublicCombos;

public class PublicComboDto
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public int TotalDifficulty { get; set; }
    public int TrickCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public string DisplayText { get; set; } = string.Empty;
    public string? AiDescription { get; set; }
    public double AverageRating { get; set; }
    public int TotalRatings { get; set; }
}
