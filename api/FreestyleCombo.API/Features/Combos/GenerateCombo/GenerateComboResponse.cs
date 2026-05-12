namespace FreestyleCombo.API.Features.Combos.GenerateCombo;

public class GenerateComboResponse
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public string? OwnerUserName { get; set; }
    public string? Name { get; set; }
    public double TotalDifficulty { get; set; }
    public int TrickCount { get; set; }
    public bool IsPublic { get; set; }
    public bool IsReusable { get; set; }
    public string Visibility { get; set; } = "Private";
    public DateTime CreatedAt { get; set; }
    public string DisplayText { get; set; } = string.Empty;
    public string? AiDescription { get; set; }
    public List<ComboTrickDto> Tricks { get; set; } = [];
    public List<string> Warnings { get; set; } = [];
}

public class ComboTrickDto
{
    public string Type { get; set; } = "trick";  // "trick" | "combo"

    // Populated when Type == "trick"
    public Guid? TrickId { get; set; }
    public string? Name { get; set; }
    public string? Abbreviation { get; set; }
    public int Position { get; set; }
    public bool StrongFoot { get; set; }
    public bool NoTouch { get; set; }
    public int Difficulty { get; set; }
    public decimal Revolution { get; set; }
    public bool CrossOver { get; set; }
    public bool IsTransition { get; set; }

    // Populated when Type == "combo"
    public Guid? SubComboId { get; set; }
    public string? SubComboName { get; set; }
    public List<ComboTrickDto>? SubComboTricks { get; set; }
}
