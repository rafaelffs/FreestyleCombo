using FreestyleCombo.API.Features.Combos.GenerateCombo;

namespace FreestyleCombo.API.Features.Combos.GetCombo;

public class ComboDetailDto
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public int TotalDifficulty { get; set; }
    public int TrickCount { get; set; }
    public bool IsPublic { get; set; }
    public DateTime CreatedAt { get; set; }
    public string DisplayText { get; set; } = string.Empty;
    public string? AiDescription { get; set; }
    public List<ComboTrickDto> Tricks { get; set; } = [];
    public double AverageRating { get; set; }
    public int TotalRatings { get; set; }
}
