namespace FreestyleCombo.AI.Models;

public class ComboEnhancementRequest
{
    public List<TrickInfo> Tricks { get; set; } = [];
    public double AverageDifficulty { get; set; }
}

public class TrickInfo
{
    public string Name { get; set; } = string.Empty;
    public string Abbreviation { get; set; } = string.Empty;
    public decimal Revolution { get; set; }
    public bool CrossOver { get; set; }
    public int Difficulty { get; set; }
    public bool StrongFoot { get; set; }
    public bool NoTouch { get; set; }
    public int Position { get; set; }
}
