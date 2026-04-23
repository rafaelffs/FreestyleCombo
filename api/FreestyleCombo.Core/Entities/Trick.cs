namespace FreestyleCombo.Core.Entities;

public class Trick
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Abbreviation { get; set; } = string.Empty;
    public bool CrossOver { get; set; }
    public bool Knee { get; set; }
    public decimal Revolution { get; set; }
    public int Difficulty { get; set; }
    public int CommonLevel { get; set; }
    public bool IsTransition { get; set; }
    public string? CreatedBy { get; set; }
    public DateOnly? DateCreated { get; set; }
    public string? Notes { get; set; }

    public ICollection<ComboTrick> ComboTricks { get; set; } = [];
}
