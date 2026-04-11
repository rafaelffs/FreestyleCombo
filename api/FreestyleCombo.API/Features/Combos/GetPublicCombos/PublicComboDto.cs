using FreestyleCombo.API.Features.Combos.GenerateCombo;

namespace FreestyleCombo.API.Features.Combos.GetPublicCombos;

public class PublicComboDto
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public string? OwnerUserName { get; set; }
    public string? Name { get; set; }
    public double AverageDifficulty { get; set; }
    public int TrickCount { get; set; }
    public bool IsPublic { get; set; }
    public string Visibility { get; set; } = "Private";
    public DateTime CreatedAt { get; set; }
    public string DisplayText { get; set; } = string.Empty;
    public string? AiDescription { get; set; }
    public List<ComboTrickDto> Tricks { get; set; } = [];
    public double AverageRating { get; set; }
    public int TotalRatings { get; set; }
    public bool IsFavourited { get; set; }
}
