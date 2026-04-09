namespace FreestyleCombo.Core.Entities;

public class ComboTrick
{
    public Guid Id { get; set; }
    public Guid ComboId { get; set; }
    public Guid TrickId { get; set; }
    public int Position { get; set; }
    public bool StrongFoot { get; set; }
    public bool NoTouch { get; set; }

    public Combo Combo { get; set; } = null!;
    public Trick Trick { get; set; } = null!;
}
