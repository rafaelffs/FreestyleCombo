namespace FreestyleCombo.API.Features.Tricks.GetTricks;

public record TrickDto(Guid Id, string Name, string Abbreviation, bool CrossOver, bool Knee, decimal Motion, int Difficulty, int CommonLevel);
